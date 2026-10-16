from __future__ import annotations

from abc import ABC, abstractmethod
from app.models.character import InterviewerPersona
from app.models.memory import CharacterMemory
from app.models.session import ConversationSession, CharacterRelationship


class CharacterRepository(ABC):
    """Abstract interface for character persistence."""

    @abstractmethod
    def get(self, character_id: str, include_deleted: bool = False) -> InterviewerPersona | None:
        """Retrieve a character by ID."""
        pass

    @abstractmethod
    def list(self, include_deleted: bool = False) -> list[InterviewerPersona]:
        """List active characters (or all if include_deleted is True)."""
        pass

    @abstractmethod
    def list_deleted(self) -> list[InterviewerPersona]:
        """List soft-deleted characters in the Bin."""
        pass

    @abstractmethod
    def create(self, character: InterviewerPersona) -> InterviewerPersona:
        """Persist a new character."""
        pass

    @abstractmethod
    def update(self, character: InterviewerPersona) -> InterviewerPersona:
        """Update an existing character."""
        pass

    @abstractmethod
    def delete(self, character_id: str) -> bool:
        """Soft delete a character by ID (moves to Bin)."""
        pass

    @abstractmethod
    def soft_delete(self, character_id: str) -> bool:
        """Soft delete a character by ID (moves to Bin)."""
        pass

    @abstractmethod
    def restore(self, character_id: str) -> bool:
        """Restore a soft-deleted character from the Bin."""
        pass

    @abstractmethod
    def permanent_delete(self, character_id: str) -> bool:
        """Permanently delete a character and all its associated data."""
        pass

    @abstractmethod
    def empty_bin(self) -> int:
        """Permanently delete all characters in the Bin and return the count."""
        pass


class MemoryRepository(ABC):
    """Abstract interface for memory persistence."""

    @abstractmethod
    def get_memories(
        self, character_id: str, user_id: str = "default_user", limit: int = 10
    ) -> list[CharacterMemory]:
        """Retrieve top memories for a character and user ordered by importance and recency."""
        pass

    @abstractmethod
    def add_memory(self, memory: CharacterMemory) -> CharacterMemory:
        """Store a new memory."""
        pass

    @abstractmethod
    def add_memories(self, memories: list[CharacterMemory]) -> list[CharacterMemory]:
        """Store multiple memories in batch."""
        pass

    @abstractmethod
    def delete_memory(self, memory_id: str) -> bool:
        """Delete a single memory by ID."""
        pass

    @abstractmethod
    def clear_memories(self, character_id: str, user_id: str = "default_user") -> int:
        """Delete all memories for a character and user."""
        pass


class SessionRepository(ABC):
    """Abstract interface for conversation session persistence."""

    @abstractmethod
    def create_session(self, session: ConversationSession) -> ConversationSession:
        """Create a new conversation session."""
        pass

    @abstractmethod
    def get_session(self, session_id: str) -> ConversationSession | None:
        """Retrieve a session by ID."""
        pass

    @abstractmethod
    def end_session(
        self, session_id: str, ended_at: str | None = None
    ) -> ConversationSession | None:
        """Mark a session as ended."""
        pass


class RelationshipRepository(ABC):
    """Abstract interface for user-character relationship persistence."""

    @abstractmethod
    def get_relationship(
        self, character_id: str, user_id: str = "default_user"
    ) -> CharacterRelationship:
        """Get or initialize the relationship state between user and character."""
        pass

    @abstractmethod
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
        """Update relationship metrics after a session or interaction."""
        pass

