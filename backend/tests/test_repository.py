import tempfile
from pathlib import Path

import pytest
from app.models.character import (
    Behavior,
    InterviewerPersona,
    Personality,
    Story,
    VoiceProfile,
)
from app.repositories.sqlite import SQLiteCharacterRepository


@pytest.fixture
def temp_repo():
    with tempfile.TemporaryDirectory() as tmp_dir:
        db_path = Path(tmp_dir) / "test_fitcheck.db"
        repo = SQLiteCharacterRepository(db_path=db_path)
        yield repo


def test_repository_seed(temp_repo):
    # Should seed demo Raj automatically
    characters = temp_repo.list()
    assert len(characters) == 1
    assert characters[0].id == "raj-roommate-001"
    assert characters[0].name == "Raj"


def test_repository_create_and_get(temp_repo):
    maya = InterviewerPersona(
        id="maya-teacher-002",
        name="Maya",
        age=30,
        role="Language Teacher",
        appearance="Warm smile and graceful demeanor.",
        personality=Personality(
            traits=["calm", "patient", "empathetic"],
            patience=0.95,
            empathy=0.9,
            humor=0.4,
        ),
        story=Story(
            backstory="A gentle teacher passionate about literature and communication.",
            goals=["Help students speak with confidence."],
        ),
        behavior=Behavior(
            rules=["Always speak encouragingly", "Never raise voice"],
            likes=["Books", "Languages", "Tea"],
        ),
        voice=VoiceProfile(
            description="Warm, gentle, soothing tone.",
            tone="Warm and encouraging",
            speaking_style="Patient and articulate",
        ),
        languages=["English", "Spanish", "Hindi"],
    )

    created = temp_repo.create(maya)
    assert created.id == "maya-teacher-002"

    retrieved = temp_repo.get("maya-teacher-002")
    assert retrieved is not None
    assert retrieved.name == "Maya"
    assert retrieved.role == "Language Teacher"
    assert retrieved.personality.patience == 0.95

    # List should now return both Raj and Maya
    all_chars = temp_repo.list()
    assert len(all_chars) == 2
    assert {c.id for c in all_chars} == {"raj-roommate-001", "maya-teacher-002"}


def test_repository_duplicate_create_error(temp_repo):
    with pytest.raises(ValueError):
        temp_repo.create(temp_repo.list()[0])


def test_repository_update(temp_repo):
    char = temp_repo.get("raj-roommate-001")
    assert char is not None
    updated_char = char.model_copy(update={"name": "Rajesh"})
    temp_repo.update(updated_char)

    retrieved = temp_repo.get("raj-roommate-001")
    assert retrieved.name == "Rajesh"


def test_repository_delete(temp_repo):
    assert temp_repo.delete("raj-roommate-001") is True
    assert temp_repo.get("raj-roommate-001") is None
    assert len(temp_repo.list()) == 0
    assert temp_repo.delete("non-existent") is False
