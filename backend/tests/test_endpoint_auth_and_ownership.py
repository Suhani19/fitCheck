import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.auth import AuthenticatedUser, get_current_user
from app.db.database import Base, get_db
from app.db.models import UserModel
from app.db.seed_presets import seed_interviewer_presets
from app.main import app


@pytest.fixture
def test_db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()
    seed_interviewer_presets(db)

    # Pre-populate test users
    db.add(UserModel(id="user-alice", email="alice@test.com", display_name="Alice"))
    db.add(UserModel(id="user-bob", email="bob@test.com", display_name="Bob"))
    db.commit()

    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def client(test_db_session):
    def override_get_db():
        yield test_db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def test_public_routes_accessible_without_auth(client):
    """GET /health and GET /debug/config must be accessible without authentication."""
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["status"] == "ok"

    resp = client.get("/debug/config")
    assert resp.status_code == 200


def test_protected_v1_endpoints_reject_unauthenticated(client):
    """All FitCheck v1 endpoints must reject unauthenticated requests with 401."""
    endpoints = [
        ("GET", "/api/v1/candidates"),
        ("POST", "/api/v1/candidates"),
        ("GET", "/api/v1/candidates/some-id"),
        ("PUT", "/api/v1/candidates/some-id"),
        ("DELETE", "/api/v1/candidates/some-id"),
        ("GET", "/api/v1/jobs"),
        ("POST", "/api/v1/jobs"),
        ("GET", "/api/v1/jobs/some-id"),
        ("PUT", "/api/v1/jobs/some-id"),
        ("DELETE", "/api/v1/jobs/some-id"),
        ("GET", "/api/v1/interviewers"),
        ("POST", "/api/v1/interviewers"),
        ("GET", "/api/v1/interviewers/some-id"),
        ("DELETE", "/api/v1/interviewers/some-id"),
        ("GET", "/api/v1/sessions"),
        ("POST", "/api/v1/sessions"),
        ("GET", "/api/v1/sessions/some-id"),
        ("POST", "/api/v1/sessions/some-id/end"),
        ("GET", "/api/v1/evaluations"),
        ("GET", "/api/v1/evaluations/some-id"),
    ]

    for method, path in endpoints:
        if method == "GET":
            resp = client.get(path)
        elif method == "POST":
            resp = client.post(path, json={})
        elif method == "PUT":
            resp = client.put(path, json={})
        elif method == "DELETE":
            resp = client.delete(path)
        assert resp.status_code == 401, f"{method} {path} should return 401 Unauthorized"
        assert "Missing or invalid" in resp.json()["detail"]


def test_cross_user_candidate_isolation_via_http(client, test_db_session):
    """User Bob cannot read, list, update, or delete User Alice's candidate."""
    # Authenticate as Alice
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(uid="user-alice", email="alice@test.com")

    create_resp = client.post("/api/v1/candidates", json={
        "full_name": "Alice Candidate",
        "headline": "Full-Stack Dev",
        "skills": ["Dart", "Python"],
    })
    assert create_resp.status_code == 201
    cand_id = create_resp.json()["id"]

    # Alice can read her own candidate
    alice_get = client.get(f"/api/v1/candidates/{cand_id}")
    assert alice_get.status_code == 200
    assert alice_get.json()["full_name"] == "Alice Candidate"

    # Now switch caller to Bob
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(uid="user-bob", email="bob@test.com")

    # Bob's candidate list must be empty
    bob_list = client.get("/api/v1/candidates")
    assert bob_list.status_code == 200
    assert len(bob_list.json()) == 0

    # Bob cannot GET Alice's candidate
    bob_get = client.get(f"/api/v1/candidates/{cand_id}")
    assert bob_get.status_code == 404

    # Bob cannot PUT Alice's candidate
    bob_put = client.put(f"/api/v1/candidates/{cand_id}", json={"full_name": "Bob Hacked"})
    assert bob_put.status_code == 404

    # Bob cannot DELETE Alice's candidate
    bob_del = client.delete(f"/api/v1/candidates/{cand_id}")
    assert bob_del.status_code == 404

    # Switch back to Alice: verify record was not modified or deleted
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(uid="user-alice", email="alice@test.com")
    alice_verify = client.get(f"/api/v1/candidates/{cand_id}")
    assert alice_verify.status_code == 200
    assert alice_verify.json()["full_name"] == "Alice Candidate"


def test_cross_user_job_isolation_via_http(client, test_db_session):
    """User Bob cannot access or modify User Alice's Job."""
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(uid="user-alice")

    create_resp = client.post("/api/v1/jobs", json={
        "title": "Backend Lead",
        "seniority": "lead",
        "description": "Lead the platform architecture.",
        "competencies": [{"name": "System Design"}],
    })
    assert create_resp.status_code == 201
    job_id = create_resp.json()["id"]

    # Switch to Bob
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(uid="user-bob")

    assert client.get("/api/v1/jobs").json() == []
    assert client.get(f"/api/v1/jobs/{job_id}").status_code == 404
    assert client.put(f"/api/v1/jobs/{job_id}", json={"title": "Hacked"}).status_code == 404
    assert client.delete(f"/api/v1/jobs/{job_id}").status_code == 404


def test_interviewer_presets_and_custom_isolation_via_http(client, test_db_session):
    """Built-in presets are visible to all; custom interviewers are strictly isolated."""
    # Alice lists interviewers: sees 3 presets
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(uid="user-alice")
    alice_list = client.get("/api/v1/interviewers").json()
    assert len(alice_list) >= 3
    assert any(i["id"] == "sarah-em-001" for i in alice_list)

    # Alice creates custom interviewer
    create_resp = client.post("/api/v1/interviewers", json={
        "name": "Alice Custom Interviewer",
        "title": "Staff Engineer",
        "questioning_style": "rigorous",
    })
    assert create_resp.status_code == 201
    custom_id = create_resp.json()["id"]

    # Bob lists interviewers: sees presets, but NOT Alice's custom interviewer
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(uid="user-bob")
    bob_list = client.get("/api/v1/interviewers").json()
    assert any(i["id"] == "sarah-em-001" for i in bob_list)
    assert not any(i["id"] == custom_id for i in bob_list)

    # Bob cannot GET or DELETE Alice's custom interviewer
    assert client.get(f"/api/v1/interviewers/{custom_id}").status_code == 404
    assert client.delete(f"/api/v1/interviewers/{custom_id}").status_code == 404

    # Bob cannot DELETE built-in preset
    assert client.delete("/api/v1/interviewers/sarah-em-001").status_code == 404


def test_cross_resource_session_creation_forbidden(client, test_db_session):
    """User Bob cannot start a session referencing Alice's Candidate or Job."""
    # Alice creates Candidate and Job
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(uid="user-alice")
    cand_id = client.post("/api/v1/candidates", json={"full_name": "Alice Cand"}).json()["id"]
    job_id = client.post("/api/v1/jobs", json={"title": "Engineer", "description": "Build"}).json()["id"]

    # Bob attempts to start a session using Alice's candidate
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(uid="user-bob")
    bob_cand_id = client.post("/api/v1/candidates", json={"full_name": "Bob Cand"}).json()["id"]

    # 1. Bob tries Alice's job -> 404
    resp1 = client.post("/api/v1/sessions", json={
        "candidate_id": bob_cand_id,
        "job_id": job_id,
        "interviewer_id": "sarah-em-001",
    })
    assert resp1.status_code == 404
    assert "Job not found" in resp1.json()["detail"]

    # 2. Bob tries Alice's candidate -> 404
    bob_job_id = client.post("/api/v1/jobs", json={"title": "Bob Job", "description": "Build"}).json()["id"]
    resp2 = client.post("/api/v1/sessions", json={
        "candidate_id": cand_id,
        "job_id": bob_job_id,
        "interviewer_id": "sarah-em-001",
    })
    assert resp2.status_code == 404
    assert "Candidate not found" in resp2.json()["detail"]
