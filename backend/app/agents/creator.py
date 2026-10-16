import os
import re
import uuid

from google import genai
from google.genai import types

from app.models.character import InterviewerPersona


class CreatorAgent:
    """Creates a structured FitCheck interviewer persona from a natural-language description."""

    def __init__(self) -> None:
        api_key = os.getenv("GEMINI_API_KEY")

        if not api_key:
            raise RuntimeError("GEMINI_API_KEY is not configured.")

        self.client = genai.Client(api_key=api_key)

    async def create_character(self, description: str) -> InterviewerPersona:
        prompt = f"""
Create a complete FitCheck technical interviewer persona from the user's description below.

FitCheck interviewer personas should feel like rigorous, professional industry practitioners (e.g. Bar Raisers, Staff Architects, Engineering Managers), not generic AI assistants.

Infer reasonable details where the user is silent, but never contradict
anything explicitly stated.

Pay particular attention to:
- distinct personality traits
- believable backstory
- relationships and experiences
- behavioral rules
- likes, dislikes and emotional triggers
- secrets that can make conversations interesting
- voice and speaking style
- languages the character can naturally speak

The character should be internally consistent.
Do not invent conversation memories, relationship history with the user,
or current emotional state. Runtime state will be initialized separately.

User's character description:
{description}
"""

        response = await self.client.aio.models.generate_content(
            model="gemini-3.5-flash-lite",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=InterviewerPersona,
            ),
        )

        if not response.parsed:
            raise RuntimeError("Gemini returned no structured character.")

        character = InterviewerPersona.model_validate(response.parsed)

        # Ensure persistent voice is assigned immediately upon creation
        from app.services.voice_selector import VoiceSelector

        if not character.voice.voice_id:
            character.voice.voice_id = VoiceSelector.determine_voice(character)
            character.voice.provider = "gemini"

        # Enforce unique, collision-free ID formatted as {name_slug}-{unique_suffix}
        name_slug = re.sub(r"[^a-zA-Z0-9]+", "-", character.name.lower()).strip("-")
        if not name_slug:
            name_slug = "interviewer"
        unique_suffix = uuid.uuid4().hex[:6]
        return character.model_copy(update={"id": f"{name_slug}-{unique_suffix}"})