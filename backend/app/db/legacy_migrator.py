import json
import logging
import os
import sqlite3
from pathlib import Path
from sqlalchemy.orm import Session

from app.db.models import (
    ArchivedInterviewerModel,
    CandidatePracticeMemoryModel,
    ArchivedMetadataModel,
    ArchivedRelationshipModel,
    ArchivedSessionModel,
)

logger = logging.getLogger(__name__)


def migrate_legacy_sqlite_data(db: Session, sqlite_path: str | Path | None = None) -> dict[str, int]:
    """Safely and idempotently transfers existing legacy data into preservation tables."""
    if sqlite_path is None:
        base_dir = Path(__file__).resolve().parent.parent.parent
        sqlite_path = base_dir / "data" / "fitcheck.db"

    path_str = str(sqlite_path)
    if not os.path.exists(path_str):
        logger.info("No legacy SQLite database found at %s. Skipping migration.", path_str)
        return {
            "characters": 0,
            "sessions": 0,
            "memories": 0,
            "relationships": 0,
        }

    conn = sqlite3.connect(path_str)
    conn.row_factory = sqlite3.Row
    counts = {
        "characters": 0,
        "sessions": 0,
        "memories": 0,
        "relationships": 0,
    }

    try:
        # 1. Characters / Interviewers
        cursor = conn.execute("SELECT id, name, role, data, deleted_at, created_at, updated_at FROM characters;")
        for row in cursor.fetchall():
            existing = db.query(ArchivedInterviewerModel).filter(ArchivedInterviewerModel.id == row["id"]).first()
            if not existing:
                db.add(
                    ArchivedInterviewerModel(
                        id=row["id"],
                        name=row["name"],
                        role=row["role"],
                        data=row["data"],
                        deleted_at=str(row["deleted_at"]) if row["deleted_at"] else None,
                        created_at=str(row["created_at"]) if row["created_at"] else None,
                        updated_at=str(row["updated_at"]) if row["updated_at"] else None,
                    )
                )
                counts["characters"] += 1

        # 2. Sessions
        cursor = conn.execute("SELECT id, character_id, user_id, channel, agent_id, status, started_at, ended_at FROM conversation_sessions;")
        for row in cursor.fetchall():
            existing = db.query(ArchivedSessionModel).filter(ArchivedSessionModel.id == row["id"]).first()
            if not existing:
                db.add(
                    ArchivedSessionModel(
                        id=row["id"],
                        character_id=row["character_id"],
                        user_id=row["user_id"],
                        channel=row["channel"],
                        agent_id=row["agent_id"],
                        status=row["status"],
                        started_at=str(row["started_at"]) if row["started_at"] else None,
                        ended_at=str(row["ended_at"]) if row["ended_at"] else None,
                    )
                )
                counts["sessions"] += 1

        # 3. Memories / Practice Memories
        cursor = conn.execute("SELECT id, character_id, user_id, session_id, content, category, importance, created_at, updated_at FROM character_memories;")
        for row in cursor.fetchall():
            existing = db.query(CandidatePracticeMemoryModel).filter(CandidatePracticeMemoryModel.id == row["id"]).first()
            if not existing:
                db.add(
                    CandidatePracticeMemoryModel(
                        id=row["id"],
                        character_id=row["character_id"],
                        user_id=row["user_id"],
                        session_id=row["session_id"],
                        content=row["content"],
                        category=row["category"],
                        importance=float(row["importance"]),
                        created_at=str(row["created_at"]) if row["created_at"] else None,
                        updated_at=str(row["updated_at"]) if row["updated_at"] else None,
                    )
                )
                counts["memories"] += 1

        # 4. Relationships
        cursor = conn.execute("SELECT character_id, user_id, relationship_score, trust, familiarity, affection, respect, tension, milestones, total_sessions, last_session_at, created_at, updated_at FROM character_relationships;")
        for row in cursor.fetchall():
            existing = (
                db.query(ArchivedRelationshipModel)
                .filter(
                    ArchivedRelationshipModel.character_id == row["character_id"],
                    ArchivedRelationshipModel.user_id == row["user_id"],
                )
                .first()
            )
            if not existing:
                db.add(
                    ArchivedRelationshipModel(
                        character_id=row["character_id"],
                        user_id=row["user_id"],
                        relationship_score=float(row["relationship_score"]),
                        trust=float(row["trust"]),
                        familiarity=float(row["familiarity"]),
                        affection=float(row["affection"]),
                        respect=float(row["respect"]),
                        tension=float(row["tension"]),
                        milestones=str(row["milestones"]) if row["milestones"] else "[]",
                        total_sessions=float(row["total_sessions"]),
                        last_session_at=str(row["last_session_at"]) if row["last_session_at"] else None,
                        created_at=str(row["created_at"]) if row["created_at"] else None,
                        updated_at=str(row["updated_at"]) if row["updated_at"] else None,
                    )
                )
                counts["relationships"] += 1

        # 5. App Metadata
        counts["metadata"] = 0
        try:
            cursor = conn.execute("SELECT key, value FROM app_metadata;")
            for row in cursor.fetchall():
                existing = db.query(ArchivedMetadataModel).filter(ArchivedMetadataModel.key == row["key"]).first()
                if not existing:
                    db.add(
                        ArchivedMetadataModel(
                            key=row["key"],
                            value=str(row["value"]),
                        )
                    )
                    counts["metadata"] += 1
        except sqlite3.OperationalError:
            pass

        db.commit()
        logger.info("Migrated legacy data: %s", counts)
    finally:
        conn.close()

    return counts
