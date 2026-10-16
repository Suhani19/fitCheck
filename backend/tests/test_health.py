from starlette.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health_check():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["service"] == "fitcheck-api"


def test_debug_config():
    response = client.get("/debug/config")
    assert response.status_code == 200
    data = response.json()
    assert "gemini_configured" in data
    assert "agora_configured" in data
