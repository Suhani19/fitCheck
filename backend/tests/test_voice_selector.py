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
from app.services.voice_selector import VoiceSelector


@pytest.fixture
def temp_db():
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir) / "test_voice.db"


def _create_test_character(char_id: str, name: str, appearance: str, voice_desc: str, voice_id: str | None = None) -> InterviewerPersona:
    return InterviewerPersona(
        id=char_id,
        name=name,
        role="Guide",
        appearance=appearance,
        personality=Personality(),
        story=Story(),
        behavior=Behavior(),
        voice=VoiceProfile(
            voice_id=voice_id,
            description=voice_desc,
        ),
        languages=["English"],
    )


def test_existing_voice_preserved():
    char = _create_test_character(
        "char-custom", "Custom", "A robot", "Neutral", voice_id="Charon"
    )
    voice = VoiceSelector.get_or_assign_voice(char)
    assert voice == "Charon"
    assert char.voice.voice_id == "Charon"


def test_female_character_gets_aoede(temp_db):
    repo = SQLiteCharacterRepository(db_path=temp_db)
    maya = _create_test_character(
        "maya-001",
        "Maya",
        "A serene 26-year-old woman and yoga teacher",
        "A soft, gentle, feminine voice",
        voice_id=None,
    )
    repo.create(maya)

    # First call assigns and persists
    voice = VoiceSelector.get_or_assign_voice(maya, repository=repo)
    assert voice == "Aoede"
    assert maya.voice.voice_id == "Aoede"

    # Verify persisted in SQLite
    reloaded = repo.get("maya-001")
    assert reloaded is not None
    assert reloaded.voice.voice_id == "Aoede"
    assert reloaded.voice.provider == "gemini"


def test_male_character_gets_puck(temp_db):
    repo = SQLiteCharacterRepository(db_path=temp_db)
    arjun = _create_test_character(
        "arjun-001",
        "Arjun",
        "A tall young man with glasses",
        "A deep masculine voice",
        voice_id=None,
    )
    repo.create(arjun)

    voice = VoiceSelector.get_or_assign_voice(arjun, repository=repo)
    assert voice == "Puck"
    assert arjun.voice.voice_id == "Puck"

    # Verify persisted
    reloaded = repo.get("arjun-001")
    assert reloaded.voice.voice_id == "Puck"


def test_maya_teacher_gets_aoede(temp_db):
    repo = SQLiteCharacterRepository(db_path=temp_db)
    maya = InterviewerPersona(
        id="maya-teacher-002",
        name="Maya",
        age=30,
        role="Language Teacher",
        appearance="Warm smile and elegant glasses.",
        personality=Personality(traits=["calm", "patient", "thoughtful"]),
        story=Story(
            backstory="A passionate language teacher who loves world literature.",
            relationships=["Teacher and mentor to user"],
            experiences=["Taught languages globally"],
            goals=["Help students express themselves clearly"],
        ),
        behavior=Behavior(rules=["Be encouraging and patient"]),
        secrets=["Struggled with shyness in her youth"],
        voice=VoiceProfile(
            provider="gemini",
            voice_id=None,
            description="A soothing, articulate and gentle tone",
        ),
        languages=["English", "Spanish", "Hindi"],
    )
    repo.create(maya)

    assigned = VoiceSelector.get_or_assign_voice(maya, repository=repo)
    assert assigned == "Aoede"
    assert maya.voice.voice_id == "Aoede"

    # Verify persisted in database
    reloaded = repo.get("maya-teacher-002")
    assert reloaded is not None
    assert reloaded.voice.voice_id == "Aoede"
    assert reloaded.voice.provider == "gemini"


def test_deterministic_fallback():
    char_a = _create_test_character(
        "neutral-id-1",
        "Alex",
        "A friendly assistant",
        "Clear and helpful",
        voice_id=None,
    )
    voice_1 = VoiceSelector.determine_voice(char_a)
    voice_2 = VoiceSelector.determine_voice(char_a)
    assert voice_1 == voice_2
    assert voice_1 in ["Aoede", "Puck"]
