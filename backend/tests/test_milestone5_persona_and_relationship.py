import tempfile
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from starlette.testclient import TestClient

from app.agents.runtime_prompt import build_character_system_prompt
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
from app.models.session import (
    CharacterRelationship,
    ConversationSession,
    RelationshipDelta,
)
from app.services.memory_extractor import SessionAnalysisResult
from app.repositories.sqlite import (
    SQLiteCharacterRepository,
    SQLiteMemoryRepository,
    SQLiteRelationshipRepository,
    SQLiteSessionRepository,
)


def _make_test_character(name: str, role: str) -> InterviewerPersona:
    return InterviewerPersona(
        id=f"char-{name.lower()}",
        name=name,
        role=role,
        appearance=f"A typical {role.lower()}",
        personality=Personality(traits=["authentic", "candid"]),
        story=Story(backstory=f"Works as a {role.lower()}."),
        behavior=Behavior(rules=["Stay authentic"]),
        voice=VoiceProfile(provider="gemini", voice_id="Aoede"),
        languages=["English", "Hindi"],
    )


def test_character_knowledge_boundary_in_prompt():
    """Verify that character prompt distinguishes model vs character knowledge."""
    barber = _make_test_character("Vikram", "Neighborhood Barber")
    barber_prompt = build_character_system_prompt(barber)

    # 1. Knowledge boundary rules must exist
    assert "CRITICAL: CHARACTER KNOWLEDGE BOUNDARIES" in barber_prompt
    assert "DISTINGUISH MODEL KNOWLEDGE VS. CHARACTER KNOWLEDGE" in barber_prompt
    assert "Neighborhood Barber" in barber_prompt

    # 2. Must prohibit out-of-domain expert explanations
    assert "DO NOT explain them!" in barber_prompt or "barber" in barber_prompt.lower()
    assert "authenticity is more important than answer completeness" in barber_prompt.lower()
    assert "anti-assistant rules" in barber_prompt.lower()

    # 3. Software engineer prompt should have their role emphasized
    dev = _make_test_character("Siddharth", "Software Engineer")
    dev_prompt = build_character_system_prompt(dev)
    assert "Software Engineer" in dev_prompt


def test_relationship_5d_dimensions_and_connection_levels():
    """Verify 5-dimensional relationship metrics, bounds, and connection level."""
    rel = CharacterRelationship(
        character_id="char-1",
        user_id="u1",
        trust=20,
        familiarity=10,
        affection=15,
        respect=30,
        tension=0,
    )
    assert rel.connection_level == "New Acquaintance"

    # Getting Familiar
    rel.familiarity = 25
    assert rel.connection_level == "Getting Familiar"

    # Comfortable level
    rel.familiarity = 45
    assert rel.connection_level == "Comfortable"

    # Close Connection level
    rel.familiarity = 75
    assert rel.connection_level == "Close Connection"

    # Tension overrides
    rel.tension = 55
    assert rel.connection_level == "Tense / Strained"


def test_sqlite_relationship_5d_evolution_and_milestones():
    """Verify updating SQLite relationship tracks 5D deltas and triggers milestones."""
    with tempfile.TemporaryDirectory() as tmp_dir:
        db_path = Path(tmp_dir) / "rel_test.db"
        repo = SQLiteRelationshipRepository(db_path=db_path)

        # Baseline
        rel0 = repo.get_relationship(character_id="char-1", user_id="u1")
        assert rel0.trust == 20
        assert rel0.familiarity == 10
        assert rel0.tension == 0

        # Session 1: positive interaction
        rel1 = repo.update_relationship(
            character_id="char-1",
            user_id="u1",
            trust_delta=10,
            familiarity_delta=15,
            affection_delta=10,
            respect_delta=5,
            tension_delta=-5,
            new_milestone="Shared laughs over cooking mishap",
        )
        assert rel1.trust == 30
        assert rel1.familiarity == 25
        assert rel1.total_sessions == 1
        assert "First conversation" in rel1.milestones
        assert "Shared laughs over cooking mishap" in rel1.milestones

        # Session 2: high familiarity unlocks "Became familiar" milestone
        rel2 = repo.update_relationship(
            character_id="char-1",
            user_id="u1",
            familiarity_delta=20,  # 25 + 20 = 45 (>= 40)
        )
        assert rel2.familiarity == 45
        assert "Became familiar" in rel2.milestones

        # Session 3: argument increases tension
        rel3 = repo.update_relationship(
            character_id="char-1",
            user_id="u1",
            tension_delta=45,  # tension >= 40
        )
        assert rel3.tension == 45
        assert "Significant disagreement" in rel3.milestones

        # Metrics are bounded [0, 100]
        rel4 = repo.update_relationship(
            character_id="char-1",
            user_id="u1",
            trust_delta=200,
            tension_delta=-100,
        )
        assert rel4.trust == 100
        assert rel4.tension == 0


@pytest.fixture
def m5_test_setup():
    with tempfile.TemporaryDirectory() as tmp_dir:
        db_path = Path(tmp_dir) / "m5_test.db"
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


def test_session_end_extracts_and_updates_5d_relationship(m5_test_setup):
    """End-to-end test of single-pass analysis extracting memories and 5D delta."""
    client = m5_test_setup["client"]
    sess_repo = m5_test_setup["sess_repo"]
    rel_repo = m5_test_setup["rel_repo"]

    # Start session
    sess = ConversationSession(
        id="m5-sess-1",
        character_id="raj-roommate-001",
        user_id="user-m5",
        channel="fitcheck_m5_test",
    )
    sess_repo.create_session(sess)

    # Mock single-pass MemoryExtractor.extract_session_data
    mock_memories = [
        ExtractedMemory(
            content="User loves spicy chai in the morning",
            category="preference",
            importance=0.8,
        )
    ]
    mock_delta = RelationshipDelta(
        trust_change=5,
        familiarity_change=8,
        affection_change=6,
        respect_change=4,
        tension_change=-2,
        new_milestone="Morning tea discussion",
        summary_of_interaction="Warm conversation about morning routines.",
    )

    with patch("app.main.MemoryExtractor") as mock_extractor_cls:
        mock_instance = MagicMock()
        mock_instance.extract_session_data = AsyncMock(
            return_value=(mock_memories, mock_delta)
        )
        mock_extractor_cls.return_value = mock_instance

        resp = client.post(
            "/runtime/session/m5-sess-1/end",
            json={
                "transcript": [
                    {"role": "user", "text": "I love spicy chai first thing in the morning."},
                    {"role": "assistant", "text": "Finally, someone with good taste! What spices do you add?"},
                ]
            },
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ended"
        assert data["memories_extracted"] == 1
        assert data["relationship_updated"] is True
        assert data["relationship"]["trust"] == 25  # 20 + 5
        assert data["relationship"]["familiarity"] == 18  # 10 + 8
        assert "Morning tea discussion" in data["relationship"]["milestones"]

    # Also test GET /characters/{character_id}/relationship
    get_rel_resp = client.get(
        "/characters/raj-roommate-001/relationship?user_id=user-m5"
    )
    assert get_rel_resp.status_code == 200
    rel_data = get_rel_resp.json()
    assert rel_data["trust"] == 25
    assert rel_data["familiarity"] == 18
    assert rel_data["connection_level"] == "Getting Familiar"
