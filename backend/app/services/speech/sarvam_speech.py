from app.services.speech.base import SpeechProvider


class SarvamSpeechProvider(SpeechProvider):
    """Placeholder / future adapter for Sarvam AI Indic Speech-to-Text."""

    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key

    async def transcribe(self, audio_bytes: bytes, mime_type: str = "audio/m4a") -> str:
        raise NotImplementedError(
            "SarvamSpeechProvider is an architectural placeholder for future Indic STT evaluation. "
            "Set FITCHECK_SPEECH_PROVIDER=gemini to use the active provider."
        )
