from datetime import datetime, timezone
from enum import Enum
from pydantic import BaseModel, Field


class BaseEmotion(str, Enum):
    NEUTRAL = "neutral"
    HAPPY = "happy"
    AMUSED = "amused"
    SAD = "sad"
    DEFENSIVE = "defensive"
    EXCITED = "excited"


class EmotionState(BaseModel):
    emotion: str = Field(default=BaseEmotion.NEUTRAL.value, description="Current base emotion")
    intensity: float = Field(default=0.35, ge=0.0, le=1.0, description="Normalized intensity 0.0 to 1.0")
    updated_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat(),
        description="ISO 8601 UTC timestamp of last emotion update",
    )
    reason: str = Field(default="initial_state", description="Reason or trigger for current emotional state")


class EmotionDetectRequest(BaseModel):
    character_id: str
    user_text: str
    character_response: str = ""
    current_emotion: str = "neutral"
    current_intensity: float = 0.35
    user_id: str = "default_user"


class EmotionDetectResponse(BaseModel):
    character_id: str
    previous_emotion: str
    detected_emotion: str
    intensity: float
    reason: str
    transition: str
    updated_at: str
