import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
from starlette.testclient import TestClient

from app.dependencies import get_character_repository
from app.main import app
from app.models.character import (
    Behavior,
    InterviewerPersona,
    Personality,
    Story,
    VoiceProfile,
)
from app.repositories.sqlite import SQLiteCharacterRepository


@pytest.fixture
def client_with_both_characters():
    with tempfile.TemporaryDirectory() as tmp_dir:
        db_path = Path(tmp_dir) / "runtime_test.db"
        repo = SQLiteCharacterRepository(db_path=db_path)

        # Seed Maya as well
        maya = InterviewerPersona(
            id="maya-teacher-002",
            name="Maya",
            age=30,
            role="Language Teacher",
            appearance="Warm and scholarly.",
            personality=Personality(traits=["calm", "patient", "thoughtful"]),
            story=Story(backstory="Teaches languages calmly."),
            behavior=Behavior(rules=["Encourage user"]),
            voice=VoiceProfile(
                description="Calm teacher",
                tone="Calm and warm",
                speaking_style="Patient",
            ),
            languages=["English", "Hindi"],
        )
        repo.create(maya)

        app.dependency_overrides[get_character_repository] = lambda: repo
        with TestClient(app) as client:
            yield client
        app.dependency_overrides.clear()


@patch("app.main.RuntimeAgent")
def test_runtime_session_with_raj(mock_runtime_agent_cls, client_with_both_characters):
    mock_runtime_instance = MagicMock()
    mock_runtime_instance.start.return_value = "mock-raj-agent-id-123"
    mock_runtime_agent_cls.return_value = mock_runtime_instance

    resp = client_with_both_characters.post(
        "/runtime/session",
        json={"character_id": "raj-roommate-001"},
    )

    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "started"
    assert data["character_id"] == "raj-roommate-001"
    assert data["character_name"] == "Raj"
    assert data["agent_id"] == "mock-raj-agent-id-123"

    # Verify RuntimeAgent.start was called with character named Raj
    mock_runtime_instance.start.assert_called_once()
    passed_character = mock_runtime_instance.start.call_args.kwargs["character"]
    assert passed_character.name == "Raj"
    assert passed_character.id == "raj-roommate-001"


@patch("app.main.RuntimeAgent")
def test_runtime_session_with_maya(mock_runtime_agent_cls, client_with_both_characters):
    mock_runtime_instance = MagicMock()
    mock_runtime_instance.start.return_value = "mock-maya-agent-id-456"
    mock_runtime_agent_cls.return_value = mock_runtime_instance

    resp = client_with_both_characters.post(
        "/runtime/session",
        json={"character_id": "maya-teacher-002"},
    )

    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "started"
    assert data["character_id"] == "maya-teacher-002"
    assert data["character_name"] == "Maya"
    assert data["agent_id"] == "mock-maya-agent-id-456"

    # Verify RuntimeAgent.start was called with character named Maya
    mock_runtime_instance.start.assert_called_once()
    passed_character = mock_runtime_instance.start.call_args.kwargs["character"]
    assert passed_character.name == "Maya"
    assert passed_character.id == "maya-teacher-002"
    assert passed_character.role == "Language Teacher"


def test_runtime_session_unknown_character_returns_404(client_with_both_characters):
    resp = client_with_both_characters.post(
        "/runtime/session",
        json={"character_id": "unknown-ghost-999"},
    )
    assert resp.status_code == 404
    assert "not found" in resp.json()["detail"].lower()
