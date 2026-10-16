import logging
import os
from google import genai
from google.genai import types
from pydantic import BaseModel, Field

from app.models.character import InterviewerPersona
from app.models.memory import ExtractedMemory, MemoryExtractionResult
from app.models.session import (
    CharacterRelationship,
    RelationshipDelta,
    TranscriptTurn,
)

logger = logging.getLogger(__name__)


class SessionAnalysisResult(BaseModel):
    memories: list[ExtractedMemory] = Field(
        default_factory=list,
        description="Durable facts, preferences, events, or promises learned about the user.",
    )
    relationship_delta: RelationshipDelta = Field(
        default_factory=RelationshipDelta,
        description="Gradual shifts in trust, familiarity, affection, respect, and tension based on the conversation.",
    )


class MemoryExtractor:
    """Extracts persistent memories and relationship dynamics from conversation transcripts."""

    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        if self.api_key:
            self.client = genai.Client(api_key=self.api_key)
        else:
            self.client = None

    async def extract_session_data(
        self,
        transcript: list[TranscriptTurn],
        character: InterviewerPersona,
        relationship: CharacterRelationship | None = None,
    ) -> tuple[list[ExtractedMemory], RelationshipDelta]:
        """Analyzes transcript to extract memories and relationship shifts in a single LLM call."""
        if not transcript or len(transcript) == 0:
            return [], RelationshipDelta(familiarity_change=0)

        valid_turns = [
            turn for turn in transcript if turn.text and turn.text.strip()
        ]
        if not valid_turns:
            return [], RelationshipDelta(familiarity_change=0)

        # Baseline fallback if Gemini is offline
        default_delta = RelationshipDelta(
            trust_change=2,
            familiarity_change=5,
            affection_change=2,
            respect_change=2,
            tension_change=0,
            summary_of_interaction="Pleasant brief conversation.",
        )

        if not self.client:
            logger.warning(
                "GEMINI_API_KEY not configured. Using deterministic fallback for relationship update."
            )
            return [], default_delta

        formatted_dialogue = []
        for turn in valid_turns:
            speaker = (
                "User"
                if turn.role.lower() in ("user", "candidate")
                else character.name
            )
            formatted_dialogue.append(f"{speaker}: {turn.text.strip()}")

        dialogue_text = "\n".join(formatted_dialogue)
        current_trust = relationship.trust if relationship else 20
        current_familiarity = relationship.familiarity if relationship else 10
        current_tension = relationship.tension if relationship else 0

        def _fallback_memories() -> list[ExtractedMemory]:
            fallback = []
            for t in valid_turns:
                if t.role.lower() in ("user", "candidate"):
                    text = t.text.strip()
                    lt = text.lower()
                    if any(kw in lt for kw in ["built", "designed", "deployed", "implemented", "engineered", "architected", "raft", "go", "kafka", "consensus"]):
                        fallback.append(
                            ExtractedMemory(
                                content=f"Candidate experience: {text[:140]}",
                                category="fact",
                                importance=0.85,
                            )
                        )
            return fallback

        prompt = f"""
You are the Cognitive & Performance Evaluation Engine for FitCheck.

Review the conversation between the user and character '{character.name}'.
Current relationship standing: Trust={current_trust}/100, Familiarity={current_familiarity}/100, Tension={current_tension}/100.

1. MEMORY EXTRACTION:
Extract durable, meaningful memories about the user and their relationship with {character.name}.
DO NOT extract trivial small talk, conversational filler, greetings, or goodbyes (e.g. "hi", "how are you").
DO extract:
- Facts about the user (profession, family, pets, projects, background).
- User preferences (food, music, hobbies, dislikes).
- Important events, interviews, deadlines, commitments.
- Shared promises or plans.

2. RELATIONSHIP DYNAMICS:
Evaluate how this interaction affected their human relationship. Changes must be GRADUAL (typically -10 to +10):
- trust_change (-15 to +15): Increases with honest openness, consistency; decreases with lying, betrayal.
- familiarity_change (0 to +15): Increases naturally as they talk and get to know each other (usually +4 to +8).
- affection_change (-15 to +15): Increases with warm banter, shared humor, kindness; decreases with hostility.
- respect_change (-15 to +15): Increases with thoughtful/insightful discussion; decreases with dismissiveness.
- tension_change (-20 to +25): Increases with argument, rudeness, insulting character; decreases with resolution, apology, warm tone.
- new_milestone: Set if a meaningful milestone was reached (e.g. 'Inside joke formed', 'Shared recurring topic', 'Significant disagreement', 'Trust established', 'Reconciliation').

Conversation Transcript:
{dialogue_text}
"""

        try:
            response = await self.client.aio.models.generate_content(
                model="gemini-3.5-flash-lite",
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=SessionAnalysisResult,
                    temperature=0.2,
                ),
            )

            if response.parsed:
                if isinstance(response.parsed, SessionAnalysisResult):
                    mems = response.parsed.memories or _fallback_memories()
                    return mems, response.parsed.relationship_delta
                elif hasattr(response.parsed, "memories"):
                    mems = response.parsed.memories or _fallback_memories()
                    return mems, default_delta
            return _fallback_memories(), default_delta
        except Exception as exc:
            logger.error("Failed to analyze session via Gemini: %s", exc)
            return _fallback_memories(), default_delta

    async def extract_memories(
        self,
        transcript: list[TranscriptTurn],
        character: InterviewerPersona,
    ) -> list[ExtractedMemory]:
        """Backward-compatible helper that delegates to extract_session_data."""
        memories, _ = await self.extract_session_data(transcript, character)
        return memories
