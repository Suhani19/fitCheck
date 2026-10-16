from functools import lru_cache
from app.repositories.base import (
    CharacterRepository,
    MemoryRepository,
    RelationshipRepository,
    SessionRepository,
)
from app.repositories.sqlite import (
    SQLiteCharacterRepository,
    SQLiteMemoryRepository,
    SQLiteRelationshipRepository,
    SQLiteSessionRepository,
)


@lru_cache(maxsize=1)
def get_character_repository() -> CharacterRepository:
    """Dependency provider returning singleton SQLiteCharacterRepository."""
    return SQLiteCharacterRepository()


@lru_cache(maxsize=1)
def get_memory_repository() -> MemoryRepository:
    """Dependency provider returning singleton SQLiteMemoryRepository."""
    return SQLiteMemoryRepository()


@lru_cache(maxsize=1)
def get_session_repository() -> SessionRepository:
    """Dependency provider returning singleton SQLiteSessionRepository."""
    return SQLiteSessionRepository()


@lru_cache(maxsize=1)
def get_relationship_repository() -> RelationshipRepository:
    """Dependency provider returning singleton SQLiteRelationshipRepository."""
    return SQLiteRelationshipRepository()

