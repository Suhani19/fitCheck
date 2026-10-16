import io
from unittest.mock import AsyncMock, patch

import pytest
from starlette.testclient import TestClient

from app.main import app
from app.services.speech import (
    GeminiSpeechProvider,
    SarvamSpeechProvider,
    get_speech_provider,
)


def test_speech_provider_factory_default(monkeypatch):
    monkeypatch.delenv("FITCHECK_SPEECH_PROVIDER", raising=False)
    get_speech_provider.cache_clear()
    provider = get_speech_provider()
    assert isinstance(provider, GeminiSpeechProvider)


def test_speech_provider_factory_sarvam(monkeypatch):
    monkeypatch.setenv("FITCHECK_SPEECH_PROVIDER", "sarvam")
    get_speech_provider.cache_clear()
    provider = get_speech_provider()
    assert isinstance(provider, SarvamSpeechProvider)
    get_speech_provider.cache_clear()


def test_speech_provider_factory_invalid(monkeypatch):
    monkeypatch.setenv("FITCHECK_SPEECH_PROVIDER", "unsupported_xyz")
    get_speech_provider.cache_clear()
    with pytest.raises(ValueError, match="Unsupported speech provider"):
        get_speech_provider()
    get_speech_provider.cache_clear()


@pytest.mark.asyncio
async def test_sarvam_provider_raises_not_implemented():
    provider = SarvamSpeechProvider()
    with pytest.raises(NotImplementedError):
        await provider.transcribe(b"fake_audio_bytes")


def test_api_transcribe_speech():
    mock_provider = AsyncMock()
    mock_provider.transcribe.return_value = "I want a cheerful chef named Pierre."

    app.dependency_overrides[get_speech_provider] = lambda: mock_provider
    try:
        client = TestClient(app)
        audio_file = io.BytesIO(b"RIFFdummydataWAVE")
        response = client.post(
            "/speech/transcribe",
            files={"file": ("audio.wav", audio_file, "audio/wav")},
        )

        assert response.status_code == 200
        assert response.json()["transcript"] == "I want a cheerful chef named Pierre."
    finally:
        app.dependency_overrides.clear()


def test_api_transcribe_speech_empty_file():
    client = TestClient(app)
    empty_file = io.BytesIO(b"")
    response = client.post(
        "/speech/transcribe",
        files={"file": ("empty.wav", empty_file, "audio/wav")},
    )

    assert response.status_code == 200
    assert response.json()["transcript"] == ""


def test_resolve_audio_mime_type():
    from app.services.speech.mime import resolve_audio_mime_type

    # Specific audio content-type is preserved
    assert resolve_audio_mime_type("audio/wav", "recording.m4a") == "audio/wav"
    assert resolve_audio_mime_type("audio/m4a", "unknown.bin") == "audio/m4a"

    # application/octet-stream resolves based on filename
    assert resolve_audio_mime_type("application/octet-stream", "recording.m4a") == "audio/m4a"
    assert resolve_audio_mime_type("application/octet-stream", "speech.wav") == "audio/wav"
    assert resolve_audio_mime_type("application/octet-stream", "speech.webm") == "audio/webm"
    assert resolve_audio_mime_type("application/octet-stream", "speech.aac") == "audio/aac"
    assert resolve_audio_mime_type("application/octet-stream", "speech.mp3") == "audio/mp3"

    # None content-type resolves based on filename
    assert resolve_audio_mime_type(None, "recording.m4a") == "audio/m4a"
    assert resolve_audio_mime_type(None, "speech.wav") == "audio/wav"

    # Default fallback when extension unknown
    assert resolve_audio_mime_type("application/octet-stream", "test.unknown") == "audio/m4a"
    assert resolve_audio_mime_type(None, None) == "audio/m4a"


def test_api_transcribe_speech_resolves_octet_stream_mime():
    mock_provider = AsyncMock()
    mock_provider.transcribe.return_value = "Transcription of m4a recording."

    app.dependency_overrides[get_speech_provider] = lambda: mock_provider
    try:
        client = TestClient(app)
        audio_file = io.BytesIO(b"dummy_m4a_bytes")
        # Simulating client sending application/octet-stream with .m4a filename
        response = client.post(
            "/speech/transcribe",
            files={"file": ("recording.m4a", audio_file, "application/octet-stream")},
        )

        assert response.status_code == 200
        assert response.json()["transcript"] == "Transcription of m4a recording."
        # Verify speech_provider received audio/m4a, NOT application/octet-stream
        mock_provider.transcribe.assert_awaited_once_with(
            b"dummy_m4a_bytes",
            mime_type="audio/m4a",
        )
    finally:
        app.dependency_overrides.clear()

