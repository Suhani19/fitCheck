import tempfile
from pathlib import Path
import pytest

from app.models.memory import CharacterMemory, MemoryCategory
from app.models.session import ConversationSession
from app.repositories.sqlite import (
    SQLiteCharacterRepository,
    SQLiteMemoryRepository,
    SQLiteRelationshipRepository,
    SQLiteSessionRepository,
)


@pytest.fixture
def temp_db():
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir) / "test_fitcheck.db"


def test_sqlite_memory_repository(temp_db):
    repo = SQLiteMemoryRepository(db_path=temp_db)

    # 1. Add memories for user A and character 1
    m1 = CharacterMemory(
        id="mem-1",
        character_id="char-1",
        user_id="user-A",
        content="User loves spicy biryani",
        category=MemoryCategory.PREFERENCE.value,
        importance=0.8,
    )
    m2 = CharacterMemory(
        id="mem-2",
        character_id="char-1",
        user_id="user-A",
        content="User has a cat named Luna",
        category=MemoryCategory.FACT.value,
        importance=0.6,
    )
    m3 = CharacterMemory(
        id="mem-3",
        character_id="char-1",
        user_id="user-A",
        content="User has a big interview on Monday",
        category=MemoryCategory.EVENT.value,
        importance=0.95,
    )
    # Memory for another user
    m_other_user = CharacterMemory(
        id="mem-4",
        character_id="char-1",
        user_id="user-B",
        content="User dislikes garlic",
        category=MemoryCategory.PREFERENCE.value,
        importance=0.99,
    )

    repo.add_memories([m1, m2, m3, m_other_user])

    # 2. Retrieve memories for user-A: should be ordered by importance DESC
    memories_a = repo.get_memories(character_id="char-1", user_id="user-A")
    assert len(memories_a) == 3
    assert memories_a[0].id == "mem-3"  # 0.95
    assert memories_a[1].id == "mem-1"  # 0.8
    assert memories_a[2].id == "mem-2"  # 0.6

    # 3. Isolation check: user-B has only 1 memory
    memories_b = repo.get_memories(character_id="char-1", user_id="user-B")
    assert len(memories_b) == 1
    assert memories_b[0].id == "mem-4"

    # 4. Limit check
    memories_limit = repo.get_memories(character_id="char-1", user_id="user-A", limit=2)
    assert len(memories_limit) == 2

    # 5. Delete single memory
    deleted = repo.delete_memory("mem-2")
    assert deleted is True
    assert len(repo.get_memories(character_id="char-1", user_id="user-A")) == 2

    # 6. Clear memories
    cleared = repo.clear_memories(character_id="char-1", user_id="user-A")
    assert cleared == 2
    assert len(repo.get_memories(character_id="char-1", user_id="user-A")) == 0
    # user-B's memory remains untouched
    assert len(repo.get_memories(character_id="char-1", user_id="user-B")) == 1


def test_sqlite_session_repository(temp_db):
    repo = SQLiteSessionRepository(db_path=temp_db)

    sess = ConversationSession(
        id="session-123",
        character_id="char-1",
        user_id="user-A",
        channel="fitcheck_test_channel",
        agent_id="agent-xyz",
    )
    created = repo.create_session(sess)
    assert created.id == "session-123"
    assert created.status == "active"

    retrieved = repo.get_session("session-123")
    assert retrieved is not None
    assert retrieved.channel == "fitcheck_test_channel"
    assert retrieved.status == "active"
    assert retrieved.ended_at is None

    # End session
    ended = repo.end_session("session-123")
    assert ended is not None
    assert ended.status == "ended"
    assert ended.ended_at is not None


def test_sqlite_relationship_repository(temp_db):
    repo = SQLiteRelationshipRepository(db_path=temp_db)

    # 1. Initial relationship should be default
    rel = repo.get_relationship(character_id="char-1", user_id="user-A")
    assert rel.total_sessions == 0
    assert rel.relationship_score == 0.5
    assert rel.last_session_at is None

    # 2. Update relationship: increment sessions
    rel_up1 = repo.update_relationship(character_id="char-1", user_id="user-A")
    assert rel_up1.total_sessions == 1
    assert rel_up1.relationship_score == 0.52
    assert rel_up1.last_session_at is not None

    # 3. Explicit score update
    rel_up2 = repo.update_relationship(
        character_id="char-1",
        user_id="user-A",
        relationship_score=0.85,
        increment_sessions=True,
    )
    assert rel_up2.total_sessions == 2
    assert rel_up2.relationship_score == 0.85


def test_sqlite_character_repository_raj_voice_id(temp_db):
    repo = SQLiteCharacterRepository(db_path=temp_db)
    raj_char = repo.get("raj-roommate-001")
    assert raj_char is not None
    assert raj_char.voice.provider == "gemini"
    assert raj_char.voice.voice_id == "Puck"
