from __future__ import annotations

import json
import os
import sqlite3
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

from app.models.character import InterviewerPersona
from app.models.demo_character import raj
from app.models.memory import CharacterMemory
from app.models.session import (
    CharacterRelationship,
    ConversationSession,
    SessionStatus,
)
from app.repositories.base import (
    CharacterRepository,
    MemoryRepository,
    RelationshipRepository,
    SessionRepository,
)


def _get_default_db_path() -> str:
    base_dir = Path(__file__).resolve().parent.parent.parent
    data_dir = base_dir / "data"
    data_dir.mkdir(parents=True, exist_ok=True)
    return str(data_dir / "fitcheck.db")


class SQLiteCharacterRepository(CharacterRepository):
    """SQLite implementation of CharacterRepository."""

    def __init__(self, db_path: str | Path | None = None) -> None:
        self.db_path = str(db_path) if db_path is not None else _get_default_db_path()
        self._init_db()
        self._seed_demo_characters()

    @contextmanager
    def _get_connection(self):
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()

    def _init_db(self) -> None:
        with self._get_connection() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS characters (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    role TEXT NOT NULL,
                    data TEXT NOT NULL,
                    deleted_at TIMESTAMP DEFAULT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                """
            )
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS app_metadata (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                """
            )
            try:
                conn.execute("ALTER TABLE characters ADD COLUMN deleted_at TIMESTAMP DEFAULT NULL;")
            except sqlite3.OperationalError:
                pass
            conn.commit()

    def _seed_demo_characters(self) -> None:
        with self._get_connection() as conn:
            # Check if Raj already exists in database (active or soft-deleted)
            cursor = conn.execute("SELECT id, deleted_at FROM characters WHERE id = ?;", (raj.id,))
            existing_raj = cursor.fetchone()

            # Check if demo character was already seeded in the past
            cursor = conn.execute("SELECT value FROM app_metadata WHERE key = 'demo_seeded';")
            already_seeded = cursor.fetchone() is not None

            if existing_raj is None and not already_seeded:
                # Fresh database: seed demo character (Raj) once
                conn.execute(
                    """
                    INSERT INTO characters (id, name, role, data)
                    VALUES (?, ?, ?, ?);
                    """,
                    (raj.id, raj.name, raj.role, raj.model_dump_json()),
                )
                conn.execute(
                    """
                    INSERT OR REPLACE INTO app_metadata (key, value)
                    VALUES ('demo_seeded', '1');
                    """
                )
                conn.commit()
            elif existing_raj is not None and not already_seeded:
                # Mark as seeded so future permanent deletions won't resurrect him
                conn.execute(
                    """
                    INSERT OR REPLACE INTO app_metadata (key, value)
                    VALUES ('demo_seeded', '1');
                    """
                )
                conn.commit()

            # Ensure all characters (seeded or existing) have a persistent voice assigned
            from app.services.voice_selector import VoiceSelector

            cursor = conn.execute("SELECT id, data FROM characters WHERE deleted_at IS NULL;")
            rows = cursor.fetchall()
            for row in rows:
                char_id = row["id"]
                char_obj = InterviewerPersona.model_validate_json(row["data"])
                if not char_obj.voice.voice_id:
                    selected_voice = VoiceSelector.determine_voice(char_obj)
                    char_obj.voice.voice_id = selected_voice
                    char_obj.voice.provider = "gemini"
                    conn.execute(
                        "UPDATE characters SET data = ? WHERE id = ?;",
                        (char_obj.model_dump_json(), char_id),
                    )
            conn.commit()

    def get(self, character_id: str, include_deleted: bool = False) -> InterviewerPersona | None:
        with self._get_connection() as conn:
            if include_deleted:
                cursor = conn.execute(
                    "SELECT data FROM characters WHERE id = ?;",
                    (character_id,),
                )
            else:
                cursor = conn.execute(
                    "SELECT data FROM characters WHERE id = ? AND deleted_at IS NULL;",
                    (character_id,),
                )
            row = cursor.fetchone()
            if row is None:
                return None
            return InterviewerPersona.model_validate_json(row["data"])

    def list(self, include_deleted: bool = False) -> list[InterviewerPersona]:
        with self._get_connection() as conn:
            if include_deleted:
                cursor = conn.execute(
                    "SELECT data FROM characters ORDER BY created_at ASC;"
                )
            else:
                cursor = conn.execute(
                    "SELECT data FROM characters WHERE deleted_at IS NULL ORDER BY created_at ASC;"
                )
            rows = cursor.fetchall()
            return [InterviewerPersona.model_validate_json(row["data"]) for row in rows]

    def list_deleted(self) -> list[InterviewerPersona]:
        with self._get_connection() as conn:
            cursor = conn.execute(
                "SELECT data FROM characters WHERE deleted_at IS NOT NULL ORDER BY deleted_at DESC;"
            )
            rows = cursor.fetchall()
            return [InterviewerPersona.model_validate_json(row["data"]) for row in rows]

    def create(self, character: InterviewerPersona) -> InterviewerPersona:
        with self._get_connection() as conn:
            try:
                conn.execute(
                    """
                    INSERT INTO characters (id, name, role, data, deleted_at)
                    VALUES (?, ?, ?, ?, ?);
                    """,
                    (
                        character.id,
                        character.name,
                        character.role,
                        character.model_dump_json(),
                        character.deleted_at,
                    ),
                )
                conn.commit()
            except sqlite3.IntegrityError as exc:
                raise ValueError(
                    f"Character with id '{character.id}' already exists."
                ) from exc
            return character

    def update(self, character: InterviewerPersona) -> InterviewerPersona:
        with self._get_connection() as conn:
            cursor = conn.execute(
                """
                UPDATE characters
                SET name = ?, role = ?, data = ?, deleted_at = ?, updated_at = CURRENT_TIMESTAMP
                WHERE id = ?;
                """,
                (
                    character.name,
                    character.role,
                    character.model_dump_json(),
                    character.deleted_at,
                    character.id,
                ),
            )
            conn.commit()
            if cursor.rowcount == 0:
                raise KeyError(f"Character with id '{character.id}' not found.")
            return character

    def soft_delete(self, character_id: str) -> bool:
        now = datetime.now(timezone.utc).isoformat()
        with self._get_connection() as conn:
            cursor = conn.execute("SELECT data FROM characters WHERE id = ?;", (character_id,))
            row = cursor.fetchone()
            if not row:
                return False
            char = InterviewerPersona.model_validate_json(row["data"])
            char.deleted_at = now
            cursor = conn.execute(
                "UPDATE characters SET deleted_at = ?, data = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?;",
                (now, char.model_dump_json(), character_id),
            )
            conn.commit()
            return cursor.rowcount > 0

    def delete(self, character_id: str) -> bool:
        """Alias for soft_delete for backward compatibility."""
        return self.soft_delete(character_id)

    def restore(self, character_id: str) -> bool:
        with self._get_connection() as conn:
            cursor = conn.execute("SELECT data FROM characters WHERE id = ?;", (character_id,))
            row = cursor.fetchone()
            if not row:
                return False
            char = InterviewerPersona.model_validate_json(row["data"])
            char.deleted_at = None
            cursor = conn.execute(
                "UPDATE characters SET deleted_at = NULL, data = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?;",
                (char.model_dump_json(), character_id),
            )
            conn.commit()
            return cursor.rowcount > 0

    def permanent_delete(self, character_id: str) -> bool:
        with self._get_connection() as conn:
            for table in ("character_memories", "character_relationships", "conversation_sessions"):
                try:
                    conn.execute(f"DELETE FROM {table} WHERE character_id = ?;", (character_id,))
                except sqlite3.OperationalError:
                    pass
            cursor = conn.execute("DELETE FROM characters WHERE id = ?;", (character_id,))
            conn.commit()
            return cursor.rowcount > 0

    def empty_bin(self) -> int:
        with self._get_connection() as conn:
            cursor = conn.execute("SELECT id FROM characters WHERE deleted_at IS NOT NULL;")
            rows = cursor.fetchall()
            ids = [row["id"] for row in rows]
            if not ids:
                return 0
            for char_id in ids:
                for table in ("character_memories", "character_relationships", "conversation_sessions"):
                    try:
                        conn.execute(f"DELETE FROM {table} WHERE character_id = ?;", (char_id,))
                    except sqlite3.OperationalError:
                        pass
                conn.execute("DELETE FROM characters WHERE id = ?;", (char_id,))
            conn.commit()
            return len(ids)


class SQLiteMemoryRepository(MemoryRepository):
    """SQLite implementation of MemoryRepository."""

    def __init__(self, db_path: str | Path | None = None) -> None:
        self.db_path = str(db_path) if db_path is not None else _get_default_db_path()
        self._init_db()

    @contextmanager
    def _get_connection(self):
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()

    def _init_db(self) -> None:
        with self._get_connection() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS character_memories (
                    id TEXT PRIMARY KEY,
                    character_id TEXT NOT NULL,
                    user_id TEXT NOT NULL,
                    session_id TEXT,
                    content TEXT NOT NULL,
                    category TEXT NOT NULL,
                    importance REAL NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
                """
            )
            conn.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_memories_char_user
                ON character_memories (character_id, user_id, importance DESC);
                """
            )
            conn.commit()

    def get_memories(
        self, character_id: str, user_id: str = "default_user", limit: int = 10
    ) -> list[CharacterMemory]:
        with self._get_connection() as conn:
            cursor = conn.execute(
                """
                SELECT id, character_id, user_id, session_id, content, category, importance, created_at, updated_at
                FROM character_memories
                WHERE character_id = ? AND user_id = ?
                ORDER BY importance DESC, created_at DESC
                LIMIT ?;
                """,
                (character_id, user_id, limit),
            )
            rows = cursor.fetchall()
            return [
                CharacterMemory(
                    id=row["id"],
                    character_id=row["character_id"],
                    user_id=row["user_id"],
                    session_id=row["session_id"],
                    content=row["content"],
                    category=row["category"],
                    importance=row["importance"],
                    created_at=str(row["created_at"]),
                    updated_at=str(row["updated_at"]),
                )
                for row in rows
            ]

    def add_memory(self, memory: CharacterMemory) -> CharacterMemory:
        with self._get_connection() as conn:
            now = datetime.now(timezone.utc).isoformat()
            mem_id = memory.id or str(uuid.uuid4())
            conn.execute(
                """
                INSERT OR REPLACE INTO character_memories
                (id, character_id, user_id, session_id, content, category, importance, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                (
                    mem_id,
                    memory.character_id,
                    memory.user_id,
                    memory.session_id,
                    memory.content,
                    memory.category,
                    memory.importance,
                    memory.created_at or now,
                    now,
                ),
            )
            conn.commit()
            memory.id = mem_id
            return memory

    def add_memories(self, memories: list[CharacterMemory]) -> list[CharacterMemory]:
        res = []
        for mem in memories:
            res.append(self.add_memory(mem))
        return res

    def delete_memory(self, memory_id: str) -> bool:
        with self._get_connection() as conn:
            cursor = conn.execute(
                "DELETE FROM character_memories WHERE id = ?;", (memory_id,)
            )
            conn.commit()
            return cursor.rowcount > 0

    def clear_memories(self, character_id: str, user_id: str = "default_user") -> int:
        with self._get_connection() as conn:
            cursor = conn.execute(
                "DELETE FROM character_memories WHERE character_id = ? AND user_id = ?;",
                (character_id, user_id),
            )
            conn.commit()
            return cursor.rowcount


class SQLiteSessionRepository(SessionRepository):
    """SQLite implementation of SessionRepository."""

    def __init__(self, db_path: str | Path | None = None) -> None:
        self.db_path = str(db_path) if db_path is not None else _get_default_db_path()
        self._init_db()

    @contextmanager
    def _get_connection(self):
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()

    def _init_db(self) -> None:
        with self._get_connection() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS conversation_sessions (
                    id TEXT PRIMARY KEY,
                    character_id TEXT NOT NULL,
                    user_id TEXT NOT NULL,
                    channel TEXT NOT NULL,
                    agent_id TEXT,
                    status TEXT NOT NULL,
                    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    ended_at TIMESTAMP
                );
                """
            )
            # Reconcile stale active sessions on startup
            conn.execute(
                """
                UPDATE conversation_sessions
                SET status = 'ended', ended_at = CURRENT_TIMESTAMP
                WHERE status = 'active';
                """
            )
            conn.commit()

    def create_session(self, session: ConversationSession) -> ConversationSession:
        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT INTO conversation_sessions
                (id, character_id, user_id, channel, agent_id, status, started_at, ended_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?);
                """,
                (
                    session.id,
                    session.character_id,
                    session.user_id,
                    session.channel,
                    session.agent_id,
                    session.status,
                    session.started_at,
                    session.ended_at,
                ),
            )
            conn.commit()
            return session

    def get_session(self, session_id: str) -> ConversationSession | None:
        with self._get_connection() as conn:
            cursor = conn.execute(
                "SELECT * FROM conversation_sessions WHERE id = ?;", (session_id,)
            )
            row = cursor.fetchone()
            if not row:
                return None
            return ConversationSession(
                id=row["id"],
                character_id=row["character_id"],
                user_id=row["user_id"],
                channel=row["channel"],
                agent_id=row["agent_id"],
                status=row["status"],
                started_at=str(row["started_at"]),
                ended_at=str(row["ended_at"]) if row["ended_at"] else None,
            )

    def end_session(
        self, session_id: str, ended_at: str | None = None
    ) -> ConversationSession | None:
        now = ended_at or datetime.now(timezone.utc).isoformat()
        with self._get_connection() as conn:
            conn.execute(
                """
                UPDATE conversation_sessions
                SET status = ?, ended_at = ?
                WHERE id = ?;
                """,
                (SessionStatus.ENDED.value, now, session_id),
            )
            conn.commit()
        return self.get_session(session_id)


class SQLiteRelationshipRepository(RelationshipRepository):
    """SQLite implementation of RelationshipRepository."""

    def __init__(self, db_path: str | Path | None = None) -> None:
        self.db_path = str(db_path) if db_path is not None else _get_default_db_path()
        self._init_db()

    @contextmanager
    def _get_connection(self):
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()

    def _init_db(self) -> None:
        with self._get_connection() as conn:
            conn.execute(
                """
                CREATE TABLE IF NOT EXISTS character_relationships (
                    character_id TEXT NOT NULL,
                    user_id TEXT NOT NULL,
                    relationship_score REAL NOT NULL,
                    trust INTEGER NOT NULL DEFAULT 20,
                    familiarity INTEGER NOT NULL DEFAULT 10,
                    affection INTEGER NOT NULL DEFAULT 15,
                    respect INTEGER NOT NULL DEFAULT 30,
                    tension INTEGER NOT NULL DEFAULT 0,
                    milestones TEXT NOT NULL DEFAULT '[]',
                    total_sessions INTEGER NOT NULL,
                    last_session_at TIMESTAMP,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    PRIMARY KEY (character_id, user_id)
                );
                """
            )
            # Safe schema migration for existing databases
            for col, col_def in [
                ("trust", "INTEGER NOT NULL DEFAULT 20"),
                ("familiarity", "INTEGER NOT NULL DEFAULT 10"),
                ("affection", "INTEGER NOT NULL DEFAULT 15"),
                ("respect", "INTEGER NOT NULL DEFAULT 30"),
                ("tension", "INTEGER NOT NULL DEFAULT 0"),
                ("milestones", "TEXT NOT NULL DEFAULT '[]'"),
            ]:
                try:
                    conn.execute(f"ALTER TABLE character_relationships ADD COLUMN {col} {col_def};")
                except sqlite3.OperationalError:
                    pass
            conn.commit()

    def get_relationship(
        self, character_id: str, user_id: str = "default_user"
    ) -> CharacterRelationship:
        with self._get_connection() as conn:
            cursor = conn.execute(
                """
                SELECT *
                FROM character_relationships
                WHERE character_id = ? AND user_id = ?;
                """,
                (character_id, user_id),
            )
            row = cursor.fetchone()
            if row:
                row_keys = row.keys()
                milestones = []
                if "milestones" in row_keys and row["milestones"]:
                    try:
                        milestones = json.loads(row["milestones"])
                    except Exception:
                        milestones = []

                return CharacterRelationship(
                    character_id=row["character_id"],
                    user_id=row["user_id"],
                    relationship_score=row["relationship_score"],
                    trust=row["trust"] if "trust" in row_keys and row["trust"] is not None else 20,
                    familiarity=row["familiarity"] if "familiarity" in row_keys and row["familiarity"] is not None else 10,
                    affection=row["affection"] if "affection" in row_keys and row["affection"] is not None else 15,
                    respect=row["respect"] if "respect" in row_keys and row["respect"] is not None else 30,
                    tension=row["tension"] if "tension" in row_keys and row["tension"] is not None else 0,
                    milestones=milestones,
                    total_sessions=row["total_sessions"],
                    last_session_at=str(row["last_session_at"])
                    if row["last_session_at"]
                    else None,
                    created_at=str(row["created_at"]),
                    updated_at=str(row["updated_at"]),
                )
            # Default new relationship
            return CharacterRelationship(
                character_id=character_id,
                user_id=user_id,
                relationship_score=0.5,
                trust=20,
                familiarity=10,
                affection=15,
                respect=30,
                tension=0,
                milestones=[],
                total_sessions=0,
            )

    def update_relationship(
        self,
        character_id: str,
        user_id: str = "default_user",
        relationship_score: float | None = None,
        trust_delta: int = 0,
        familiarity_delta: int = 0,
        affection_delta: int = 0,
        respect_delta: int = 0,
        tension_delta: int = 0,
        new_milestone: str | None = None,
        increment_sessions: bool = True,
        last_session_at: str | None = None,
    ) -> CharacterRelationship:
        now = last_session_at or datetime.now(timezone.utc).isoformat()
        current = self.get_relationship(character_id, user_id)
        new_total = (
            current.total_sessions + 1 if increment_sessions else current.total_sessions
        )

        # Calculate new bounded scores (0-100)
        new_trust = max(0, min(100, current.trust + trust_delta))
        new_familiarity = max(0, min(100, current.familiarity + familiarity_delta))
        new_affection = max(0, min(100, current.affection + affection_delta))
        new_respect = max(0, min(100, current.respect + respect_delta))
        new_tension = max(0, min(100, current.tension + tension_delta))

        # Update milestones
        milestones = list(current.milestones)
        if new_total >= 1 and "First conversation" not in milestones:
            milestones.append("First conversation")
        if new_milestone and new_milestone not in milestones:
            milestones.append(new_milestone)
        if new_familiarity >= 40 and "Became familiar" not in milestones:
            milestones.append("Became familiar")
        if new_trust >= 60 and "Trust established" not in milestones:
            milestones.append("Trust established")
        if new_familiarity >= 70 and "Long-term familiarity" not in milestones:
            milestones.append("Long-term familiarity")
        if new_tension >= 40 and "Significant disagreement" not in milestones:
            milestones.append("Significant disagreement")

        # Composite relationship score
        if relationship_score is not None:
            new_score = max(0.0, min(1.0, relationship_score))
        else:
            new_score = round(min(1.0, current.relationship_score + 0.02), 3)

        with self._get_connection() as conn:
            conn.execute(
                """
                INSERT INTO character_relationships
                (character_id, user_id, relationship_score, trust, familiarity, affection, respect, tension, milestones, total_sessions, last_session_at, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(character_id, user_id) DO UPDATE SET
                    relationship_score = excluded.relationship_score,
                    trust = excluded.trust,
                    familiarity = excluded.familiarity,
                    affection = excluded.affection,
                    respect = excluded.respect,
                    tension = excluded.tension,
                    milestones = excluded.milestones,
                    total_sessions = excluded.total_sessions,
                    last_session_at = excluded.last_session_at,
                    updated_at = excluded.updated_at;
                """,
                (
                    character_id,
                    user_id,
                    new_score,
                    new_trust,
                    new_familiarity,
                    new_affection,
                    new_respect,
                    new_tension,
                    json.dumps(milestones),
                    new_total,
                    now,
                    current.created_at,
                    now,
                ),
            )
            conn.commit()

        return self.get_relationship(character_id, user_id)

