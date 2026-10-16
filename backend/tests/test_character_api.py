import tempfile
from pathlib import Path

import pytest
from starlette.testclient import TestClient

from app.dependencies import get_character_repository, get_session_repository
from app.main import app
from app.repositories.sqlite import SQLiteCharacterRepository, SQLiteSessionRepository


@pytest.fixture
def client_with_temp_repo():
    with tempfile.TemporaryDirectory() as tmp_dir:
        db_path = Path(tmp_dir) / "api_test.db"
        repo = SQLiteCharacterRepository(db_path=db_path)
        sess_repo = SQLiteSessionRepository(db_path=db_path)

        app.dependency_overrides[get_character_repository] = lambda: repo
        app.dependency_overrides[get_session_repository] = lambda: sess_repo
        with TestClient(app) as client:
            yield client
        app.dependency_overrides.clear()


def test_api_list_characters(client_with_temp_repo):
    response = client_with_temp_repo.get("/characters")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["id"] == "raj-roommate-001"


def test_api_get_character_by_id(client_with_temp_repo):
    response = client_with_temp_repo.get("/characters/raj-roommate-001")
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Raj"


def test_api_get_character_404(client_with_temp_repo):
    response = client_with_temp_repo.get("/characters/non-existent-id")
    assert response.status_code == 404


def test_api_create_character(client_with_temp_repo):
    maya_payload = {
        "id": "maya-teacher-002",
        "name": "Maya",
        "age": 30,
        "role": "Language Teacher",
        "appearance": "Warm smile and glasses.",
        "personality": {
            "traits": ["calm", "patient"],
            "humor": 0.4,
            "confidence": 0.8,
            "empathy": 0.95,
            "patience": 0.95,
            "emotional_volatility": 0.2,
        },
        "story": {
            "backstory": "A passionate language teacher.",
            "relationships": ["User's mentor"],
            "experiences": [],
            "goals": ["Teach conversational fluency"],
        },
        "behavior": {
            "rules": ["Be encouraging"],
            "likes": ["Literature"],
            "dislikes": ["Rudeness"],
            "triggers": [],
            "boundaries": ["Keep lessons respectful"],
        },
        "secrets": [],
        "voice": {
            "description": "Gentle and articulate",
            "accent": "Neutral",
            "tone": "Warm and calm",
            "speaking_style": "Patient and clear",
            "energy": 0.5,
            "speed": 0.95,
        },
        "languages": ["English", "Hindi"],
        "state": {
            "current_emotion": "calm",
            "emotional_intensity": 0.1,
            "relationship_score": 0.6,
            "memories": [],
        },
    }

    create_resp = client_with_temp_repo.post("/characters", json=maya_payload)
    assert create_resp.status_code == 201
    created_data = create_resp.json()
    assert created_data["id"] == "maya-teacher-002"
    assert created_data["name"] == "Maya"

    # Verify retrieval
    get_resp = client_with_temp_repo.get("/characters/maya-teacher-002")
    assert get_resp.status_code == 200
    assert get_resp.json()["name"] == "Maya"


def test_api_update_character(client_with_temp_repo):
    get_resp = client_with_temp_repo.get("/characters/raj-roommate-001")
    char_data = get_resp.json()
    char_data["name"] = "Raj Malhotra"

    put_resp = client_with_temp_repo.put("/characters/raj-roommate-001", json=char_data)
    assert put_resp.status_code == 200
    assert put_resp.json()["name"] == "Raj Malhotra"


def test_api_delete_character(client_with_temp_repo):
    del_resp = client_with_temp_repo.delete("/characters/raj-roommate-001")
    assert del_resp.status_code == 200
    assert del_resp.json()["status"] == "deleted"

    get_resp = client_with_temp_repo.get("/characters/raj-roommate-001")
    assert get_resp.status_code == 404
