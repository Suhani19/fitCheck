import os

from google import genai
from google.genai import types

from app.services.speech.base import SpeechProvider


class GeminiSpeechProvider(SpeechProvider):
    """Speech-to-text provider using Google Gemini multimodal audio."""

    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        if not self.api_key:
            raise RuntimeError("GEMINI_API_KEY is not configured for GeminiSpeechProvider.")
        self.client = genai.Client(api_key=self.api_key)

    async def transcribe(self, audio_bytes: bytes, mime_type: str = "audio/m4a") -> str:
        if not audio_bytes:
            return ""

        # Guard against invalid or octet-stream MIME types
        clean_mime = (mime_type or "").strip().lower()
        if not clean_mime or clean_mime == "application/octet-stream":
            clean_mime = "audio/m4a"

        audio_part = types.Part.from_bytes(
            data=audio_bytes,
            mime_type=clean_mime,
        )

        prompt = (
            "Transcribe this spoken audio accurately.\n"
            "Return ONLY the exact verbatim transcription of what was spoken.\n"
            "Do not add conversational replies, explanations, notes, or commentary.\n"
            "Preserve the spoken language naturally (English, Hindi, or Hinglish as spoken).\n"
            "If the audio contains no discernible speech, return an empty string."
        )

        response = await self.client.aio.models.generate_content(
            model="gemini-3.5-flash-lite",
            contents=[prompt, audio_part],
        )

        text = response.text or ""
        return text.strip()
