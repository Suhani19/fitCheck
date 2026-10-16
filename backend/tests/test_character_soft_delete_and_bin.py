import tempfile
from pathlib import Path
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
from app.models.memory import CharacterMemory
from app.models.session import ConversationSession
from app.repositories.sqlite import (
    SQLiteCharacterRepository,
    SQLiteMemoryRepository,
    SQLiteRelationshipRepository,
    SQLiteSessionRepository,
)


def _create_sample_character(char_id: str, name: str) -> InterviewerPersona:
    return InterviewerPersona(
        id=char_id,
        name=name,
        role="Traveler",
        appearance="Traveler with a backpack",
        personality=Personality(traits=["curious", "friendly"]),
        story=Story(backstory="Travels the world."),
        behavior=Behavior(rules=["Ask questions"]),
        voice=VoiceProfile(provider="gemini", voice_id="Aoede"),
        languages=["English"],
    )


@pytest.fixture
def bin_test_setup():
    with tempfile.TemporaryDirectory() as tmp_dir:
        db_path = Path(tmp_dir) / "bin_test.db"
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


def test_soft_delete_and_bin_listing(bin_test_setup):
    """Verify soft-delete moves character to bin and hides it from active listings."""
    client = bin_test_setup["client"]
    char_repo = bin_test_setup["char_repo"]

    c1 = _create_sample_character("maya-001", "Maya")
    c2 = _create_sample_character("alex-002", "Alex")
    char_repo.create(c1)
    char_repo.create(c2)

    # 1. Both appear in active list (along with seeded Raj)
    active_resp = client.get("/characters")
    assert active_resp.status_code == 200
    active_ids = {c["id"] for c in active_resp.json()}
    assert "maya-001" in active_ids
    assert "alex-002" in active_ids

    # 2. Bin is initially empty
    bin_resp = client.get("/characters/bin")
    assert bin_resp.status_code == 200
    assert len(bin_resp.json()) == 0

    # 3. Soft-delete Maya
    del_resp = client.delete("/characters/maya-001")
    assert del_resp.status_code == 200
    assert del_resp.json()["status"] == "deleted"

    # 4. Maya no longer appears in normal active characters list
    active_resp2 = client.get("/characters")
    active_ids2 = {c["id"] for c in active_resp2.json()}
    assert "maya-001" not in active_ids2
    assert "alex-002" in active_ids2

    # 5. Normal GET /characters/maya-001 returns 404
    get_resp = client.get("/characters/maya-001")
    assert get_resp.status_code == 404

    # 6. Maya appears in GET /characters/bin
    bin_resp2 = client.get("/characters/bin")
    assert bin_resp2.status_code == 200
    bin_chars = bin_resp2.json()
    assert len(bin_chars) == 1
    assert bin_chars[0]["id"] == "maya-001"
    assert bin_chars[0]["deleted_at"] is not None


def test_restore_preserves_memory_and_relationship(bin_test_setup):
    """Verify restore brings character back with all memories and relationship intact."""
    client = bin_test_setup["client"]
    char_repo = bin_test_setup["char_repo"]
    mem_repo = bin_test_setup["mem_repo"]
    rel_repo = bin_test_setup["rel_repo"]

    c1 = _create_sample_character("maya-restore-001", "Maya")
    char_repo.create(c1)

    # Add memories and relationship
    mem = CharacterMemory(
        id="mem-1",
        character_id="maya-restore-001",
        user_id="u1",
        content="User loves tea in the morning",
        category="preference",
        importance=0.9,
    )
    mem_repo.add_memory(mem)
    rel_repo.update_relationship(
        character_id="maya-restore-001",
        user_id="u1",
        trust_delta=25,
        familiarity_delta=30,
        new_milestone="Morning tea discussion",
    )

    # Soft delete Maya
    del_resp = client.delete("/characters/maya-restore-001")
    assert del_resp.status_code == 200

    # Restore Maya
    restore_resp = client.post("/characters/maya-restore-001/restore")
    assert restore_resp.status_code == 200
    restored = restore_resp.json()
    assert restored["id"] == "maya-restore-001"
    assert restored["deleted_at"] is None

    # Verify visible again in active list
    active_resp = client.get("/characters")
    active_ids = {c["id"] for c in active_resp.json()}
    assert "maya-restore-001" in active_ids

    # Verify memories and relationship completely preserved
    mems = mem_repo.get_memories("maya-restore-001", user_id="u1")
    assert len(mems) == 1
    assert mems[0].content == "User loves tea in the morning"

    rel = rel_repo.get_relationship("maya-restore-001", user_id="u1")
    assert rel.trust == 45  # 20 base + 25
    assert rel.familiarity == 40  # 10 base + 30
    assert "Morning tea discussion" in rel.milestones


def test_permanent_delete_cascades_all_data(bin_test_setup):
    """Verify permanent delete removes character and all child memories/relationships/sessions."""
    client = bin_test_setup["client"]
    char_repo = bin_test_setup["char_repo"]
    mem_repo = bin_test_setup["mem_repo"]
    rel_repo = bin_test_setup["rel_repo"]
    sess_repo = bin_test_setup["sess_repo"]

    c1 = _create_sample_character("char-perm-001", "Zara")
    char_repo.create(c1)

    # Populate children
    mem_repo.add_memory(
        CharacterMemory(
            id="m-perm-1",
            character_id="char-perm-001",
            user_id="u1",
            content="Zara knows user lives in Tokyo",
            category="fact",
            importance=0.8,
        )
    )
    rel_repo.update_relationship("char-perm-001", "u1", trust_delta=10)
    sess_repo.create_session(
        ConversationSession(
            id="sess-perm-1",
            character_id="char-perm-001",
            channel="ch-1",
            status="ended",
        )
    )

    # Permanent delete
    perm_resp = client.delete("/characters/char-perm-001/permanent")
    assert perm_resp.status_code == 200
    assert perm_resp.json()["status"] == "permanently_deleted"

    # Verify character completely gone
    assert char_repo.get("char-perm-001", include_deleted=True) is None

    # Verify child records cleaned up (no orphaned records)
    assert len(mem_repo.get_memories("char-perm-001", "u1")) == 0
    rel = rel_repo.get_relationship("char-perm-001", "u1")
    assert rel.total_sessions == 0  # returns default new relation
    assert sess_repo.get_session("sess-perm-1") is None


def test_empty_bin_only_deletes_trashed_characters(bin_test_setup):
    """Verify empty bin permanently removes all characters in Bin while active characters stay."""
    client = bin_test_setup["client"]
    char_repo = bin_test_setup["char_repo"]

    c_active = _create_sample_character("keep-active", "ActivePerson")
    c_trash1 = _create_sample_character("trash-1", "Trash1")
    c_trash2 = _create_sample_character("trash-2", "Trash2")

    char_repo.create(c_active)
    char_repo.create(c_trash1)
    char_repo.create(c_trash2)

    client.delete("/characters/trash-1")
    client.delete("/characters/trash-2")

    bin_before = client.get("/characters/bin").json()
    assert len(bin_before) == 2

    # Empty bin
    empty_resp = client.delete("/characters/bin")
    assert empty_resp.status_code == 200
    assert empty_resp.json()["deleted_count"] == 2

    # Bin is empty
    bin_after = client.get("/characters/bin").json()
    assert len(bin_after) == 0

    # Active character still exists
    assert char_repo.get("keep-active") is not None


def test_active_call_delete_protection_and_bin_call_rejection(bin_test_setup):
    """Verify cannot delete a character on an active call, and cannot call a character in bin."""
    client = bin_test_setup["client"]
    char_repo = bin_test_setup["char_repo"]
    sess_repo = bin_test_setup["sess_repo"]

    c1 = _create_sample_character("on-call-char", "Rohan")
    char_repo.create(c1)

    # Create active session for Rohan
    sess = ConversationSession(
        id="live-call-1",
        character_id="on-call-char",
        channel="fitcheck-rohan-live",
        status="active",
    )
    sess_repo.create_session(sess)

    # Attempting to delete Rohan should be rejected with 409 Conflict
    del_resp = client.delete("/characters/on-call-char")
    assert del_resp.status_code == 409
    assert "currently on an active call" in del_resp.json()["detail"]

    # End the session
    sess_repo.end_session("live-call-1")

    # Now deletion succeeds
    del_resp2 = client.delete("/characters/on-call-char")
    assert del_resp2.status_code == 200

    # Attempting to start a call with character in the Bin should be rejected with 400 Bad Request
    call_resp = client.post(
        "/runtime/session",
        json={"character_id": "on-call-char", "user_id": "u1"},
    )
    assert call_resp.status_code == 400
    assert "in the Bin" in call_resp.json()["detail"]


def test_seeded_raj_lifecycle_soft_delete_restore_and_no_resurrection_on_restart():
    """Verify seeded Raj can be deleted, moved to bin, restored, permanently deleted,
    and restarting/reinitializing the repository does NOT resurrect him."""
    with tempfile.TemporaryDirectory() as tmp_dir:
        db_path = Path(tmp_dir) / "raj_test.db"

        # 1. First initialization: seeds Raj
        repo1 = SQLiteCharacterRepository(db_path=db_path)
        active1 = repo1.list()
        assert any(c.id == "raj-roommate-001" for c in active1)
        assert len(repo1.list_deleted()) == 0

        # 2. Soft-delete Raj
        deleted = repo1.soft_delete("raj-roommate-001")
        assert deleted is True

        # Raj is absent from active list
        assert not any(c.id == "raj-roommate-001" for c in repo1.list())
        # Raj appears in bin
        deleted_list = repo1.list_deleted()
        assert len(deleted_list) == 1
        assert deleted_list[0].id == "raj-roommate-001"
        assert deleted_list[0].deleted_at is not None

        # 3. Simulate backend restart / re-initialization with same DB while Raj is soft-deleted
        repo2 = SQLiteCharacterRepository(db_path=db_path)
        # Verify Raj was NOT resurrected as active
        assert not any(c.id == "raj-roommate-001" for c in repo2.list())
        # Verify Raj is still in the bin
        assert any(c.id == "raj-roommate-001" for c in repo2.list_deleted())

        # 4. Restore Raj
        restored = repo2.restore("raj-roommate-001")
        assert restored is True
        assert any(c.id == "raj-roommate-001" for c in repo2.list())
        assert len(repo2.list_deleted()) == 0

        # 5. Soft-delete again and permanently delete Raj
        repo2.soft_delete("raj-roommate-001")
        perm_deleted = repo2.permanent_delete("raj-roommate-001")
        assert perm_deleted is True
        assert repo2.get("raj-roommate-001", include_deleted=True) is None

        # 6. Simulate another backend restart / re-initialization with empty database
        repo3 = SQLiteCharacterRepository(db_path=db_path)
        # Seeding must be idempotent - since Raj was already seeded and deleted, he must NOT be resurrected
        assert len(repo3.list()) == 0
        assert repo3.get("raj-roommate-001", include_deleted=True) is None


def test_empty_bin_permanently_deletes_raj_and_restart_does_not_resurrect():
    """Verify emptying bin permanently deletes Raj and restarting repository does not resurrect him."""
    with tempfile.TemporaryDirectory() as tmp_dir:
        db_path = Path(tmp_dir) / "raj_empty_bin.db"

        repo1 = SQLiteCharacterRepository(db_path=db_path)
        assert any(c.id == "raj-roommate-001" for c in repo1.list())

        # Soft delete Raj
        repo1.soft_delete("raj-roommate-001")
        assert len(repo1.list_deleted()) == 1

        # Empty bin
        count = repo1.empty_bin()
        assert count == 1
        assert len(repo1.list_deleted()) == 0
        assert repo1.get("raj-roommate-001", include_deleted=True) is None

        # Simulate restart
        repo2 = SQLiteCharacterRepository(db_path=db_path)
        assert len(repo2.list()) == 0
        assert repo2.get("raj-roommate-001", include_deleted=True) is None

