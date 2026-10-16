import os
from functools import lru_cache

from app.services.speech.base import SpeechProvider
from app.services.speech.gemini_speech import GeminiSpeechProvider
from app.services.speech.sarvam_speech import SarvamSpeechProvider


@lru_cache(maxsize=1)
def get_speech_provider() -> SpeechProvider:
    """Config-driven factory for speech-to-text providers.

    Configured via `FITCHECK_SPEECH_PROVIDER` environment variable (default: 'gemini').
    """
    provider_name = (
        os.getenv("FITCHECK_SPEECH_PROVIDER")
        or "gemini"
    ).strip().lower()

    if provider_name == "gemini":
        return GeminiSpeechProvider()
    elif provider_name == "sarvam":
        return SarvamSpeechProvider()
    else:
        raise ValueError(
            f"Unsupported speech provider: '{provider_name}'. "
            "Supported values: 'gemini', 'sarvam'."
        )


from app.services.speech.mime import resolve_audio_mime_type


__all__ = [
    "SpeechProvider",
    "GeminiSpeechProvider",
    "SarvamSpeechProvider",
    "get_speech_provider",
    "resolve_audio_mime_type",
]
