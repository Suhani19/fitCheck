from abc import ABC, abstractmethod


class SpeechProvider(ABC):
    """Abstract interface for speech-to-text providers."""

    @abstractmethod
    async def transcribe(self, audio_bytes: bytes, mime_type: str = "audio/m4a") -> str:
        """Transcribe audio bytes to natural language text."""
        pass
