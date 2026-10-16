from datetime import datetime, timezone
from enum import Enum
from pydantic import BaseModel, Field, computed_field


class SessionStatus(str, Enum):
    ACTIVE = "active"
    ENDED = "ended"
    FAILED = "failed"


class ConversationSession(BaseModel):
    id: str
    character_id: str
    user_id: str = "default_user"
    channel: str
    agent_id: str | None = None
    status: str = SessionStatus.ACTIVE.value
    started_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    ended_at: str | None = None


class CharacterRelationship(BaseModel):
    character_id: str
    user_id: str = "default_user"
    relationship_score: float = Field(default=0.5, ge=0.0, le=1.0)
    trust: int = Field(default=20, ge=0, le=100)
    familiarity: int = Field(default=10, ge=0, le=100)
    affection: int = Field(default=15, ge=0, le=100)
    respect: int = Field(default=30, ge=0, le=100)
    tension: int = Field(default=0, ge=0, le=100)
    milestones: list[str] = Field(default_factory=list)
    total_sessions: int = 0
    last_session_at: str | None = None
    created_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    updated_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )

    @computed_field
    @property
    def connection_level(self) -> str:
        if self.tension >= 50:
            return "Tense / Strained"
        if self.familiarity >= 70:
            return "Close Connection"
        if self.familiarity >= 40:
            return "Comfortable"
        if self.familiarity >= 20 or self.total_sessions >= 1:
            return "Getting Familiar"
        return "New Acquaintance"


class RelationshipDelta(BaseModel):
    trust_change: int = Field(
        default=0,
        ge=-25,
        le=25,
        description="Shift in trust (-25 to +25). Decreases if user lies or betrays, increases with honesty/reliability.",
    )
    familiarity_change: int = Field(
        default=5,
        ge=0,
        le=20,
        description="Shift in familiarity (0 to +20). Increases naturally through conversation.",
    )
    affection_change: int = Field(
        default=0,
        ge=-25,
        le=25,
        description="Shift in affection (-25 to +25). Increases with shared humor/kindness, decreases with hostility.",
    )
    respect_change: int = Field(
        default=0,
        ge=-25,
        le=25,
        description="Shift in respect (-25 to +25). Increases with thoughtful discussion, decreases with dismissiveness.",
    )
    tension_change: int = Field(
        default=0,
        ge=-30,
        le=35,
        description="Shift in tension (-30 to +35). Increases with argument/rudeness, decreases with apology/resolution.",
    )
    new_milestone: str | None = Field(
        default=None,
        description="Meaningful relationship milestone unlocked if applicable (e.g., 'First conversation', 'First remembered preference', 'Inside joke formed', 'Shared recurring topic', 'Significant disagreement', 'Trust established').",
    )
    summary_of_interaction: str = Field(
        default="",
        description="Brief summary of how the conversation went emotionally and relationally.",
    )


class TranscriptTurn(BaseModel):
    role: str = Field(description="Role in dialogue: 'user' or 'assistant'")
    text: str = Field(description="Dialogue turn content")


class EndSessionRequest(BaseModel):
    transcript: list[TranscriptTurn] = Field(default_factory=list)
    notes: str | None = None


class EndSessionResponse(BaseModel):
    session_id: str
    status: str
    memories_extracted: int
    relationship_updated: bool
    relationship: CharacterRelationship | None = None
