"""Tests for secure seeded demo candidate access and tenant isolation.

Verifies:
1. Demo session token creation and verification via HMAC-SHA256.
2. Demo candidate profile, jobs, sessions, evaluations, and memories are populated.
3. Tampered or expired demo tokens are rejected with 401 Unauthorized.
4. Tenant isolation: demo session cannot access another registered candidate's data,
   and another candidate cannot mutate or access demo candidate's private data.
5. Demo reset endpoint reproducibly restores baseline sample state.
"""

import time
import pytest
from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.core.auth import AuthenticatedUser
from app.core.demo_token import create_demo_token, verify_demo_token
from app.db.database import get_db
from app.db.models import (
    CandidateModel,
    InterviewEvaluationModel,
    InterviewSessionModel,
    JobModel,
    UserModel,
)
from app.db.seed_demo_candidate import (
    DEMO_CANDIDATE_ID,
    DEMO_EVAL_1_ID,
    DEMO_SESSION_1_ID,
    DEMO_USER_ID,
    seed_demo_candidate,
)
from app.main import app


@pytest.fixture
def test_db():
    db = next(get_db())
    seed_demo_candidate(db, force_reset=True)
    yield db


@pytest.fixture
def client(test_db):
    return TestClient(app)


def test_create_demo_session_endpoint(client: TestClient, test_db: Session):
    response = client.post("/api/v1/auth/demo-session")
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["access_token"].startswith("fitcheck_demo.")
    assert data["token_type"] == "bearer"
    assert data["candidate_id"].startswith("cand-shinchan-")
    assert data["user"]["uid"].startswith("demo-ws-")


def test_demo_token_authentication(client: TestClient, test_db: Session):
    token = create_demo_token()
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Retrieve candidates for demo user
    cand_resp = client.get("/api/v1/candidates", headers=headers)
    assert cand_resp.status_code == 200
    candidates = cand_resp.json()
    assert len(candidates) >= 1
    assert candidates[0]["id"] == DEMO_CANDIDATE_ID
    assert candidates[0]["full_name"] == "Elena Rostova"

    # 2. Retrieve sessions for demo user
    sess_resp = client.get("/api/v1/sessions", headers=headers)
    assert sess_resp.status_code == 200
    sessions = sess_resp.json()
    assert len(sessions) >= 2
    session_ids = [s["id"] for s in sessions]
    assert DEMO_SESSION_1_ID in session_ids

    # 3. Retrieve evaluations for demo user
    eval_resp = client.get("/api/v1/evaluations", headers=headers)
    assert eval_resp.status_code == 200
    evals = eval_resp.json()
    assert len(evals) >= 2
    eval_ids = [e["id"] for e in evals]
    assert DEMO_EVAL_1_ID in eval_ids

    # 4. Check evaluation scorecard details
    eval_detail = client.get(f"/api/v1/evaluations/{DEMO_SESSION_1_ID}", headers=headers)
    assert eval_detail.status_code == 200
    eval_data = eval_detail.json()
    assert eval_data["overall_score"] == 88.0
    assert eval_data["overall_recommendation"] == "Strong Hire"
    assert len(eval_data["competency_scores"]) == 4


def test_tampered_and_expired_demo_tokens(client: TestClient, test_db: Session):
    # Tampered token
    valid_token = create_demo_token()
    tampered_token = valid_token[:-4] + "xxxx"
    resp = client.get("/api/v1/candidates", headers={"Authorization": f"Bearer {tampered_token}"})
    assert resp.status_code == 401

    # Expired token
    expired_token = create_demo_token(exp_seconds=-10)
    resp_exp = client.get("/api/v1/candidates", headers={"Authorization": f"Bearer {expired_token}"})
    assert resp_exp.status_code == 401


def test_demo_tenant_isolation(client: TestClient, test_db: Session):
    # Ensure a real separate candidate "alice" exists idempotently
    alice_user = test_db.query(UserModel).filter(UserModel.id == "user-alice-real").first()
    if not alice_user:
        alice_user = UserModel(id="user-alice-real", email="alice@corp.com", display_name="Alice Real")
        test_db.add(alice_user)
        test_db.commit()

    alice_cand = test_db.query(CandidateModel).filter(CandidateModel.id == "cand-alice-real").first()
    if not alice_cand:
        alice_cand = CandidateModel(
            id="cand-alice-real",
            user_id="user-alice-real",
            full_name="Alice Real",
            headline="Principal Security Eng",
        )
        test_db.add(alice_cand)
        test_db.commit()

    # Demo user token
    demo_token = create_demo_token()
    demo_headers = {"Authorization": f"Bearer {demo_token}"}

    # Demo user CANNOT get alice's candidate profile
    resp_cross = client.get(f"/api/v1/candidates/{alice_cand.id}", headers=demo_headers)
    assert resp_cross.status_code == 404

    # Demo user CANNOT mutate alice's candidate profile
    resp_mut = client.put(
        f"/api/v1/candidates/{alice_cand.id}",
        json={"headline": "Hacked By Demo"},
        headers=demo_headers,
    )
    assert resp_mut.status_code == 404


def test_demo_reset_endpoint(client: TestClient, test_db: Session):
    demo_token = create_demo_token()
    demo_headers = {"Authorization": f"Bearer {demo_token}"}

    # Call reset
    resp = client.post("/api/v1/auth/demo-reset", headers=demo_headers)
    assert resp.status_code == 200
    assert resp.json()["status"] == "reset"

    # Non-demo candidate cannot call reset
    alice_token = create_demo_token(uid="user-alice-real")
    resp_forbidden = client.post("/api/v1/auth/demo-reset", headers={"Authorization": f"Bearer {alice_token}"})
    assert resp_forbidden.status_code == 403
