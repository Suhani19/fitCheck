from datetime import datetime, timezone
from enum import Enum
from pydantic import BaseModel, Field


class MemoryCategory(str, Enum):
    FACT = "fact"
    PREFERENCE = "preference"
    EVENT = "event"
    PROMISE = "promise"
    CONFLICT = "conflict"
    SHARED_EXPERIENCE = "shared_experience"
    RELATIONSHIP = "relationship"


class CharacterMemory(BaseModel):
    id: str
    character_id: str
    user_id: str = "default_user"
    session_id: str | None = None
    content: str
    category: str = MemoryCategory.FACT.value
    importance: float = Field(default=0.5, ge=0.0, le=1.0)
    created_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    updated_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )


class ExtractedMemory(BaseModel):
    content: str = Field(
        description="A concise statement of fact, preference, event, or promise learned from the conversation."
    )
    category: str = Field(
        default=MemoryCategory.FACT.value,
        description="One of: fact, preference, event, promise, conflict, shared_experience, relationship",
    )
    importance: float = Field(
        default=0.5,
        ge=0.0,
        le=1.0,
        description="Importance score from 0.0 (trivial) to 1.0 (crucial).",
    )


class MemoryExtractionResult(BaseModel):
    memories: list[ExtractedMemory] = Field(
        default_factory=list,
        description="List of meaningful facts, preferences, events, or promises learned from the conversation.",
    )


class MemoryListResponse(BaseModel):

    character_id: str
    memories: list[CharacterMemory]
    total: int
