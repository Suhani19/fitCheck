import os
import pytest

from app.services.agora_token import AgoraTokenService


def test_agora_token_generation():
    # If environment variables are set, test actual generation
    app_id = os.getenv("AGORA_APP_ID")
    app_cert = os.getenv("AGORA_APP_CERTIFICATE")

    if not app_id or not app_cert:
        pytest.skip("AGORA_APP_ID or AGORA_APP_CERTIFICATE not set.")

    service = AgoraTokenService()
    token = service.generate_rtc_token(
        channel="test-channel",
        uid=1001,
        expires_in=3600,
    )

    assert isinstance(token, str)
    assert len(token) > 0


def test_agora_token_missing_credentials(monkeypatch):
    monkeypatch.delenv("AGORA_APP_ID", raising=False)
    monkeypatch.delenv("AGORA_APP_CERTIFICATE", raising=False)

    with pytest.raises(RuntimeError):
        AgoraTokenService()
