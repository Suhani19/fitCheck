import pytest
from unittest.mock import MagicMock, patch
from fastapi import HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.auth import AuthenticatedUser, get_current_user
from app.db.database import Base
from app.db.models import UserModel
from app.db.legacy_migrator import migrate_legacy_sqlite_data
from app.db.seed_presets import seed_interviewer_presets
from app.repositories.sql_fitcheck import (
    SQLCandidateRepository,
    SQLEvaluationRepository,
    SQLInterviewerRepository,
    SQLInterviewSessionRepository,
    SQLJobRepository,
    SQLUserRepository,
)


@pytest.fixture
def test_db():
    """In-memory SQLite database for isolated authentication and authorization tests."""
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


def test_auth_missing_token(test_db):
    """Requests with no Authorization header must fail with 401 Unauthorized."""
    with pytest.raises(HTTPException) as exc_info:
        get_current_user(auth_header=None, db=test_db)
    assert exc_info.value.status_code == status.HTTP_401_UNAUTHORIZED
    assert "Missing or invalid" in exc_info.value.detail


def test_auth_invalid_token(test_db):
    """Requests with an invalid token must fail with 401 Unauthorized."""
    cred = HTTPAuthorizationCredentials(scheme="Bearer", credentials="invalid-token-12345")
    with patch("firebase_admin.auth.verify_id_token", side_effect=Exception("Signature invalid")):
        with pytest.raises(HTTPException) as exc_info:
            get_current_user(auth_header=cred, db=test_db)
        assert exc_info.value.status_code == status.HTTP_401_UNAUTHORIZED
        assert "Invalid or expired" in exc_info.value.detail


def test_auth_valid_token_and_user_sync(test_db):
    """Valid Firebase token returns AuthenticatedUser and syncs record to users table."""
    cred = HTTPAuthorizationCredentials(scheme="Bearer", credentials="valid-token-xyz")
    mock_payload = {
        "uid": "firebase-user-123",
        "email": "candidate@example.com",
        "name": "Alex Candidate",
    }
    with patch("firebase_admin.auth.verify_id_token", return_value=mock_payload):
        user = get_current_user(auth_header=cred, db=test_db)
        assert isinstance(user, AuthenticatedUser)
        assert user.uid == "firebase-user-123"
        assert user.email == "candidate@example.com"
        assert user.display_name == "Alex Candidate"

        # Verify synced in database
        db_user = test_db.query(UserModel).filter(UserModel.id == "firebase-user-123").first()
        assert db_user is not None
        assert db_user.email == "candidate@example.com"


def test_auth_expired_token(test_db):
    """Expired tokens must fail with 401 Unauthorized."""
    cred = HTTPAuthorizationCredentials(scheme="Bearer", credentials="expired-token-xyz")
    with patch("firebase_admin.auth.verify_id_token", side_effect=Exception("Token has expired")):
        with pytest.raises(HTTPException) as exc_info:
            get_current_user(auth_header=cred, db=test_db)
        assert exc_info.value.status_code == status.HTTP_401_UNAUTHORIZED
        assert "Invalid or expired" in exc_info.value.detail


def test_auth_token_missing_uid(test_db):
    """Tokens with empty or missing UID payload must fail with 401 Unauthorized."""
    cred = HTTPAuthorizationCredentials(scheme="Bearer", credentials="valid-token-no-uid")
    mock_payload = {"email": "no-uid@example.com"}
    with patch("firebase_admin.auth.verify_id_token", return_value=mock_payload):
        with pytest.raises(HTTPException) as exc_info:
            get_current_user(auth_header=cred, db=test_db)
        assert exc_info.value.status_code == status.HTTP_401_UNAUTHORIZED
        assert "missing valid subject/uid" in exc_info.value.detail


def test_firebase_init_without_adc():
    """Firebase Admin initializes cleanly for fitcheck-by-overfit without ADC."""
    from app.core.auth import init_firebase, _DevPublicCertCredential
    import firebase_admin

    init_firebase()
    assert firebase_admin._apps is not None
    app = firebase_admin.get_app()
    assert app.project_id == "fitcheck-by-overfit"
    # Ensure credential doesn't raise DefaultCredentialsError
    assert isinstance(app.credential, _DevPublicCertCredential)


def test_candidate_ownership_isolation(test_db):
    """User B cannot access or modify a Candidate belonging to User A."""
    user_repo = SQLUserRepository(test_db)
    user_a = user_repo.get_or_create("user-a", "usera@test.com")
    user_b = user_repo.get_or_create("user-b", "userb@test.com")

    cand_repo = SQLCandidateRepository(test_db)
    created_a = cand_repo.create(
        user_id=user_a.id,
        candidate_data={
            "full_name": "Alice Candidate",
            "headline": "Senior Backend Engineer",
            "skills": ["Python", "PostgreSQL", "FastAPI"],
        },
    )

    # User A can get and list their candidate
    assert cand_repo.get(created_a.id, user_id=user_a.id) is not None
    assert len(cand_repo.list(user_id=user_a.id)) == 1

    # User B cannot access User A's candidate (returns None)
    assert cand_repo.get(created_a.id, user_id=user_b.id) is None
    assert len(cand_repo.list(user_id=user_b.id)) == 0

    # User B cannot update User A's candidate
    updated = cand_repo.update(created_a.id, user_id=user_b.id, candidate_data={"full_name": "Hacked"})
    assert updated is None

    # User B cannot delete User A's candidate
    assert cand_repo.delete(created_a.id, user_id=user_b.id) is False

    # Original candidate remains intact
    intact = cand_repo.get(created_a.id, user_id=user_a.id)
    assert intact.full_name == "Alice Candidate"


def test_job_ownership_isolation(test_db):
    """User B cannot access or modify a Job belonging to User A."""
    user_repo = SQLUserRepository(test_db)
    user_a = user_repo.get_or_create("user-a")
    user_b = user_repo.get_or_create("user-b")

    job_repo = SQLJobRepository(test_db)
    job_a = job_repo.create(
        user_id=user_a.id,
        job_data={
            "title": "Principal Architect",
            "seniority": "principal",
            "description": "Design cloud native architectures.",
            "competencies": [{"name": "Distributed Systems", "importance": "critical"}],
        },
    )

    # User A access
    assert job_repo.get(job_a.id, user_id=user_a.id) is not None
    assert len(job_repo.list(user_id=user_a.id)) == 1

    # User B cannot access, update, or delete
    assert job_repo.get(job_a.id, user_id=user_b.id) is None
    assert len(job_repo.list(user_id=user_b.id)) == 0
    assert job_repo.update(job_a.id, user_id=user_b.id, job_data={"title": "Tampered"}) is None
    assert job_repo.delete(job_a.id, user_id=user_b.id) is False


def test_interviewer_presets_and_custom_isolation(test_db):
    """Built-in presets are visible to all users; custom interviewers are strictly isolated."""
    seed_interviewer_presets(test_db)

    user_repo = SQLUserRepository(test_db)
    user_a = user_repo.get_or_create("user-a")
    user_b = user_repo.get_or_create("user-b")

    interviewer_repo = SQLInterviewerRepository(test_db)

    # Both users can see built-in presets
    presets_a = interviewer_repo.list_presets()
    assert len(presets_a) == 3
    assert interviewer_repo.get("sarah-em-001", user_id=user_a.id) is not None
    assert interviewer_repo.get("sarah-em-001", user_id=user_b.id) is not None

    # User A creates a personalized custom interviewer
    custom_a = interviewer_repo.create(
        user_id=user_a.id,
        interviewer_data={
            "name": "Custom Tech Lead",
            "title": "Staff Engineer at FinTech",
            "questioning_style": "rigorous",
            "voice_id": "Fenrir",
            "is_preset": False,
        },
    )

    # User A can see custom interviewer
    assert interviewer_repo.get(custom_a.id, user_id=user_a.id) is not None
    # User B cannot access User A's custom interviewer
    assert interviewer_repo.get(custom_a.id, user_id=user_b.id) is None
    # User B cannot delete User A's custom interviewer
    assert interviewer_repo.delete(custom_a.id, user_id=user_b.id) is False


def test_interview_session_and_evaluation_isolation(test_db):
    """User B cannot view or end an InterviewSession or read an Evaluation belonging to User A."""
    user_repo = SQLUserRepository(test_db)
    user_a = user_repo.get_or_create("user-a")
    user_b = user_repo.get_or_create("user-b")

    cand_repo = SQLCandidateRepository(test_db)
    cand_a = cand_repo.create(user_a.id, {"full_name": "Alice"})

    job_repo = SQLJobRepository(test_db)
    job_a = job_repo.create(user_a.id, {"title": "Dev", "description": "Code"})

    seed_interviewer_presets(test_db)

    sess_repo = SQLInterviewSessionRepository(test_db)
    session_a = sess_repo.create(
        user_id=user_a.id,
        session_data={
            "candidate_id": cand_a.id,
            "job_id": job_a.id,
            "interviewer_id": "sarah-em-001",
            "difficulty": "challenging",
            "channel": "fitcheck-test-channel",
        },
    )

    # Isolation check
    assert sess_repo.get(session_a.id, user_id=user_a.id) is not None
    assert sess_repo.get(session_a.id, user_id=user_b.id) is None
    assert sess_repo.end_session(session_a.id, user_id=user_b.id) is None

    # Evaluation isolation
    eval_repo = SQLEvaluationRepository(test_db)
    eval_a = eval_repo.create(
        user_id=user_a.id,
        evaluation_data={
            "session_id": session_a.id,
            "overall_score": 4.2,
            "overall_recommendation": "hire",
            "summary_verdict": "Demonstrated solid systems expertise.",
            "competency_scores": [{"competency": "Architecture", "score": 4}],
        },
    )

    assert eval_repo.get_by_session(session_a.id, user_id=user_a.id) is not None
    assert eval_repo.get_by_session(session_a.id, user_id=user_b.id) is None


def test_legacy_data_migration_safety(test_db):
    """Legacy SQLite data is safely and non-destructively copied to preservation tables."""
    import tempfile
    import sqlite3

    with tempfile.NamedTemporaryFile(suffix=".db", delete=False) as tmp:
        tmp_path = tmp.name

    try:
        # Create legacy sqlite db with sample data
        conn = sqlite3.connect(tmp_path)
        conn.execute("CREATE TABLE characters (id TEXT PRIMARY KEY, name TEXT, role TEXT, data TEXT, deleted_at TEXT, created_at TEXT, updated_at TEXT);")
        conn.execute("CREATE TABLE conversation_sessions (id TEXT PRIMARY KEY, character_id TEXT, user_id TEXT, channel TEXT, agent_id TEXT, status TEXT, started_at TEXT, ended_at TEXT);")
        conn.execute("CREATE TABLE character_memories (id TEXT PRIMARY KEY, character_id TEXT, user_id TEXT, session_id TEXT, content TEXT, category TEXT, importance REAL, created_at TEXT, updated_at TEXT);")
        conn.execute("CREATE TABLE character_relationships (character_id TEXT, user_id TEXT, relationship_score REAL, trust REAL, familiarity REAL, affection REAL, respect REAL, tension REAL, milestones TEXT, total_sessions REAL, last_session_at TEXT, created_at TEXT, updated_at TEXT, PRIMARY KEY (character_id, user_id));")
        conn.execute("CREATE TABLE app_metadata (key TEXT PRIMARY KEY, value TEXT);")

        conn.execute("INSERT INTO characters VALUES ('raj-1', 'Raj', 'Roommate', '{}', NULL, '2026-01-01', '2026-01-01');")
        conn.execute("INSERT INTO conversation_sessions VALUES ('sess-1', 'raj-1', 'u1', 'chan1', 'ag1', 'ended', '2026-01-01', '2026-01-01');")
        conn.execute("INSERT INTO character_memories VALUES ('mem-1', 'raj-1', 'u1', 'sess-1', 'Likes tea', 'preference', 0.8, '2026-01-01', '2026-01-01');")
        conn.execute("INSERT INTO character_relationships VALUES ('raj-1', 'u1', 0.5, 20.0, 10.0, 15.0, 30.0, 0.0, '[]', 1.0, '2026-01-01', '2026-01-01', '2026-01-01');")
        conn.execute("INSERT INTO app_metadata VALUES ('demo_seeded', 'true');")
        conn.commit()
        conn.close()

        # Migrate
        counts = migrate_legacy_sqlite_data(test_db, sqlite_path=tmp_path)
        assert counts["characters"] == 1
        assert counts["sessions"] == 1
        assert counts["memories"] == 1
        assert counts["relationships"] == 1
        assert counts["metadata"] == 1

        # Idempotence: migrating second time copies 0 duplicates
        counts2 = migrate_legacy_sqlite_data(test_db, sqlite_path=tmp_path)
        assert counts2["characters"] == 0
        assert counts2["sessions"] == 0
        assert counts2["metadata"] == 0
    finally:
        import os
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

