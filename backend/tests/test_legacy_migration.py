import sqlite3
from pathlib import Path
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.database import Base
from app.db.models import (
    ArchivedInterviewerModel,
    CandidatePracticeMemoryModel,
    ArchivedRelationshipModel,
    ArchivedSessionModel,
    ArchivedMetadataModel,
)
from app.db.legacy_migrator import migrate_legacy_sqlite_data


def test_sqlite_data_migration_and_idempotency():
    backend_dir = Path(__file__).resolve().parent.parent
    fitcheck_db_path = backend_dir / "data" / "fitcheck.db"

    # Count source SQLite records directly to ensure 100% preservation fidelity
    conn = sqlite3.connect(str(fitcheck_db_path))
    c_chars = conn.execute("SELECT count(*) FROM characters;").fetchone()[0]
    c_sess = conn.execute("SELECT count(*) FROM conversation_sessions;").fetchone()[0]
    c_rel = conn.execute("SELECT count(*) FROM character_relationships;").fetchone()[0]
    c_mem = conn.execute("SELECT count(*) FROM character_memories;").fetchone()[0]
    c_meta = conn.execute("SELECT count(*) FROM app_metadata;").fetchone()[0]
    conn.close()

    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(bind=engine)
    SessionLocal = sessionmaker(bind=engine)
    db = SessionLocal()

    try:
        # Run 1: Should populate from fitcheck.db with 100% completeness
        counts1 = migrate_legacy_sqlite_data(db, fitcheck_db_path)
        assert counts1["characters"] == c_chars
        assert counts1["sessions"] == c_sess
        assert counts1["relationships"] == c_rel
        assert counts1["memories"] == c_mem
        assert counts1["metadata"] == c_meta

        assert db.query(ArchivedInterviewerModel).count() == c_chars
        assert db.query(ArchivedSessionModel).count() == c_sess
        assert db.query(ArchivedRelationshipModel).count() == c_rel
        assert db.query(CandidatePracticeMemoryModel).count() == c_mem
        assert db.query(ArchivedMetadataModel).count() == c_meta

        # Run 2: Idempotent rerun, 0 added
        counts2 = migrate_legacy_sqlite_data(db, fitcheck_db_path)
        assert counts2["characters"] == 0
        assert counts2["sessions"] == 0
        assert counts2["memories"] == 0
        assert counts2["relationships"] == 0
        assert counts2["metadata"] == 0

        # Verify readability
        interviewers = db.query(ArchivedInterviewerModel).all()
        assert len(interviewers) == 6
        for iv in interviewers:
            assert iv.name and iv.role
            assert iv.data is not None

        memories = db.query(CandidatePracticeMemoryModel).all()
        assert len(memories) == 8
        for mem in memories:
            assert mem.content and mem.category
    finally:
        db.close()
