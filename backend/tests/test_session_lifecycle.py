import tempfile
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from starlette.testclient import TestClient

from app.dependencies import (
    get_character_repository,
    get_memory_repository,
    get_relationship_repository,
    get_session_repository,
)
from app.main import app
from app.models.character import (
    Behavior,
    InterviewerPersona,
    Personality,
    Story,
    VoiceProfile,
)
from app.models.memory import ExtractedMemory
from app.models.session import ConversationSession
from app.repositories.sqlite import (
    SQLiteCharacterRepository,
    SQLiteMemoryRepository,
    SQLiteRelationshipRepository,
    SQLiteSessionRepository,
)


@pytest.fixture
def test_setup():
    with tempfile.TemporaryDirectory() as tmp_dir:
        db_path = Path(tmp_dir) / "lifecycle_test.db"
        char_repo = SQLiteCharacterRepository(db_path=db_path)
        sess_repo = SQLiteSessionRepository(db_path=db_path)
        mem_repo = SQLiteMemoryRepository(db_path=db_path)
        rel_repo = SQLiteRelationshipRepository(db_path=db_path)

        app.dependency_overrides[get_character_repository] = lambda: char_repo
        app.dependency_overrides[get_session_repository] = lambda: sess_repo
        app.dependency_overrides[get_memory_repository] = lambda: mem_repo
        app.dependency_overrides[get_relationship_repository] = lambda: rel_repo

        with TestClient(app) as client:
            yield {
                "client": client,
                "char_repo": char_repo,
                "sess_repo": sess_repo,
                "mem_repo": mem_repo,
                "rel_repo": rel_repo,
            }

        app.dependency_overrides.clear()


@patch("app.main.RuntimeAgent")
def test_session_lifecycle_start_and_end_with_memories(mock_agent_cls, test_setup):
    client = test_setup["client"]
    sess_repo = test_setup["sess_repo"]
    rel_repo = test_setup["rel_repo"]
    mem_repo = test_setup["mem_repo"]

    mock_agent = MagicMock()
    mock_agent.start.return_value = "agent-lifecycle-1"
    mock_agent_cls.return_value = mock_agent

    # 1. Start session
    resp = client.post(
        "/runtime/session",
        json={"character_id": "raj-roommate-001", "user_id": "user-test-1"},
    )
    assert resp.status_code == 200
    data = resp.json()
    session_id = data["session_id"]
    assert session_id is not None
    assert data["status"] == "started"

    # Verify session recorded in repo
    saved_sess = sess_repo.get_session(session_id)
    assert saved_sess is not None
    assert saved_sess.status == "active"
    assert saved_sess.user_id == "user-test-1"

    # 2. End session with transcript (mock MemoryExtractor)
    mock_extracted = [
        ExtractedMemory(
            content="User has a major job interview at Thales next Tuesday",
            category="event",
            importance=0.9,
        ),
        ExtractedMemory(
            content="User loves mutton biryani but cannot cook",
            category="preference",
            importance=0.7,
        ),
    ]

    with patch("app.main.MemoryExtractor") as mock_extractor_cls:
        mock_extractor_instance = MagicMock()
        mock_extractor_instance.extract_memories = AsyncMock(
            return_value=mock_extracted
        )
        mock_extractor_cls.return_value = mock_extractor_instance

        end_resp = client.post(
            f"/runtime/session/{session_id}/end",
            json={
                "transcript": [
                    {"role": "assistant", "text": "Hey! What's up?"},
                    {"role": "user", "text": "I'm nervous about my Thales interview next Tuesday."},
                    {"role": "assistant", "text": "You got this, don't worry."},
                ]
            },
        )

        assert end_resp.status_code == 200
        end_data = end_resp.json()
        assert end_data["status"] == "ended"
        assert end_data["memories_extracted"] == 2
        assert end_data["relationship_updated"] is True

    # 3. Verify session marked ended
    ended_sess = sess_repo.get_session(session_id)
    assert ended_sess.status == "ended"
    assert ended_sess.ended_at is not None

    # 4. Verify relationship updated
    rel = rel_repo.get_relationship(character_id="raj-roommate-001", user_id="user-test-1")
    assert rel.total_sessions == 1
    assert rel.relationship_score == 0.52

    # 5. Verify memories saved and queryable via API
    list_resp = client.get(
        "/characters/raj-roommate-001/memories?user_id=user-test-1"
    )
    assert list_resp.status_code == 200
    memories_data = list_resp.json()
    assert memories_data["total"] == 2
    assert any("Thales" in m["content"] for m in memories_data["memories"])

    # 6. Delete a specific memory
    mem_id = memories_data["memories"][0]["id"]
    del_mem_resp = client.delete(f"/memories/{mem_id}")
    assert del_mem_resp.status_code == 200

    list_resp_2 = client.get(
        "/characters/raj-roommate-001/memories?user_id=user-test-1"
    )
    assert list_resp_2.json()["total"] == 1

    # 7. Clear all memories for character/user
    clear_resp = client.delete(
        "/characters/raj-roommate-001/memories?user_id=user-test-1"
    )
    assert clear_resp.status_code == 200
    assert clear_resp.json()["deleted_count"] == 1

    list_resp_3 = client.get(
        "/characters/raj-roommate-001/memories?user_id=user-test-1"
    )
    assert list_resp_3.json()["total"] == 0


def test_end_session_invalid_id_returns_404(test_setup):
    client = test_setup["client"]
    resp = client.post(
        "/runtime/session/non-existent-session-id/end",
        json={"transcript": []},
    )
    assert resp.status_code == 404


@patch("app.main.RuntimeAgent")
def test_end_to_end_memory_continuity_across_calls(mock_agent_cls, test_setup):
    """Verifies that facts shared in Call 1 are extracted, saved, and recalled in Call 2."""
    client = test_setup["client"]
    mem_repo = test_setup["mem_repo"]
    char_repo = test_setup["char_repo"]
    rel_repo = test_setup["rel_repo"]

    # 1. Start Call 1
    mock_agent_1 = MagicMock()
    mock_agent_1.start.return_value = "agent-call-1"
    mock_agent_cls.return_value = mock_agent_1

    resp1 = client.post(
        "/runtime/session",
        json={"character_id": "raj-roommate-001", "user_id": "interview-candidate"},
    )
    assert resp1.status_code == 200
    sess1_id = resp1.json()["session_id"]

    # 2. End Call 1 with the user's interview preparation statement
    mock_extracted = [
        ExtractedMemory(
            content="User is preparing for a big software engineering interview next month",
            category="event",
            importance=0.95,
        ),
    ]

    with patch("app.main.MemoryExtractor") as mock_extractor_cls:
        mock_extractor_instance = MagicMock()
        mock_extractor_instance.extract_memories = AsyncMock(
            return_value=mock_extracted
        )
        mock_extractor_cls.return_value = mock_extractor_instance

        end_resp = client.post(
            f"/runtime/session/{sess1_id}/end",
            json={
                "transcript": [
                    {"role": "user", "text": "I'm preparing for a big software engineering interview next month."},
                    {"role": "assistant", "text": "Whoa, that sounds huge! What company?"},
                ]
            },
        )
        assert end_resp.status_code == 200
        assert end_resp.json()["memories_extracted"] == 1

    # 3. Verify memory is in SQLite repository
    memories = mem_repo.get_memories("raj-roommate-001", user_id="interview-candidate")
    assert len(memories) == 1
    assert "software engineering interview" in memories[0].content

    # 4. Now execute a real RuntimeAgent.start flow (with mocked agora/gemini_live)
    # to verify memory retrieval and prompt construction for Call 2
    from app.agents.runtime import RuntimeAgent

    with patch("app.agents.runtime.AgoraService") as mock_agora_svc_cls, \
         patch("app.agents.runtime.GeminiLive") as mock_gemini_live_cls, \
         patch("app.agents.runtime.Agent") as mock_agent_builder_cls:

        mock_gemini_live = MagicMock()
        mock_gemini_live_cls.return_value = mock_gemini_live

        mock_builder = MagicMock()
        mock_builder.with_mllm.return_value = mock_builder
        mock_builder.create_session.return_value.start.return_value = "agent-call-2"
        mock_agent_builder_cls.return_value = mock_builder

        real_runtime = RuntimeAgent(
            character_repo=char_repo,
            relationship_repo=rel_repo,
            memory_repo=mem_repo,
        )

        char = char_repo.get("raj-roommate-001")
        agent_id_2 = real_runtime.start(
            character=char,
            channel="test-channel-call2",
            remote_uid="1001",
            user_id="interview-candidate",
        )

        assert agent_id_2 == "agent-call-2"

        # Check what arguments were passed to GeminiLive
        call_kwargs = mock_gemini_live_cls.call_args.kwargs
        instructions = call_kwargs["instructions"]
        greeting = call_kwargs["greeting_message"]
        voice = call_kwargs["voice"]

        # Voice for Raj must be Puck
        assert voice == "Puck"

        # Instructions must contain the interview memory!
        assert "User is preparing for a big software engineering interview next month" in instructions
        assert "MANDATORY MEMORY RECALL INSTRUCTIONS" in instructions
        assert "NEVER say \"I don't remember\"" in instructions
        assert "silently search the provided memories and answer directly" in instructions
        assert "Total conversations completed together: 1" in instructions

        # Returning user greeting for Raj
        assert "back" in greeting.lower()


@patch("app.main.AgoraService")
def test_agora_agent_history_fallback_when_client_transcript_empty(mock_agora_cls, test_setup):
    """Verifies that if client sends an empty transcript, the server queries Agora agent history."""
    client = test_setup["client"]
    sess_repo = test_setup["sess_repo"]

    # Create an active session with agent_id
    sess = ConversationSession(
        id="sess-fallback-1",
        character_id="raj-roommate-001",
        user_id="fallback-user",
        channel="fitcheck-raj-fallback",
        agent_id="agora-agent-fb-99",
        status="active",
    )
    sess_repo.create_session(sess)

    # Mock Agora get_history response
    mock_agora_inst = MagicMock()
    mock_agora_inst.app_id = "test-app-id"
    mock_item1 = MagicMock()
    mock_item1.role = "user"
    mock_item1.content = "I started learning French yesterday."
    mock_item2 = MagicMock()
    mock_item2.role = "assistant"
    mock_item2.content = "Bonne chance with that!"

    mock_history_resp = MagicMock()
    mock_history_resp.contents = [mock_item1, mock_item2]
    mock_agora_inst.client.agents.get_history.return_value = mock_history_resp
    mock_agora_cls.return_value = mock_agora_inst

    mock_extracted = [
        ExtractedMemory(
            content="User started learning French",
            category="preference",
            importance=0.8,
        )
    ]

    with patch("app.main.MemoryExtractor") as mock_extractor_cls:
        mock_extractor_inst = MagicMock()
        mock_extractor_inst.extract_memories = AsyncMock(return_value=mock_extracted)
        mock_extractor_cls.return_value = mock_extractor_inst

        # Client sends empty transcript
        resp = client.post(
            "/runtime/session/sess-fallback-1/end",
            json={"transcript": []},
        )

        assert resp.status_code == 200
        assert resp.json()["status"] == "ended"
        assert resp.json()["memories_extracted"] == 1

        # Verify get_history was called with agent_id
        mock_agora_inst.client.agents.get_history.assert_called_once_with(
            appid="test-app-id",
            agent_id="agora-agent-fb-99",
        )
        # Verify MemoryExtractor received the turns from Agora history
        mock_extractor_inst.extract_memories.assert_called_once()
        turns_arg = mock_extractor_inst.extract_memories.call_args.kwargs["transcript"]
        assert len(turns_arg) == 2
        assert turns_arg[0].text == "I started learning French yesterday."
        assert turns_arg[1].text == "Bonne chance with that!"
