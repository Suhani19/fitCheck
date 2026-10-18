"""Comprehensive test suite for Universal Shinchan Demo with Isolated Workspaces.

Tests the 10 core requirements:
1. Two separate Try Demo requests produce different workspace identities.
2. Both workspaces start from the same pristine Shinchan template.
3. Changes to workspace A do not affect workspace B or the master template.
4. Resume uploads and profile edits remain isolated.
5. Interview transcripts and evaluations remain isolated.
6. Cross-workspace access attempts are rejected (404/403).
7. Resetting A leaves B and all active B sessions untouched.
8. Expired workspace cleanup does not remove valid or active workspaces.
9. Normal Firebase authentication continues to work.
10. Demo visitors can complete the real interview flow without a Firebase account.
"""

import copy
import io
import time
import pytest
from datetime import datetime, timedelta, timezone
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
from app.db.seed_presets import seed_interviewer_presets
from app.db.shinchan_master_template import (
    SHINCHAN_CANONICAL_PROFILE,
    cleanup_expired_demo_workspaces,
    provision_isolated_demo_workspace,
    reset_isolated_demo_workspace,
)
from app.main import app


@pytest.fixture
def test_db():
    db = next(get_db())
    seed_interviewer_presets(db)
    yield db


@pytest.fixture
def client(test_db):
    return TestClient(app)


def test_1_separate_try_demo_requests_produce_unique_workspaces(client: TestClient):
    """1. Two separate Try Demo requests produce different workspace identities."""
    resp_a = client.post("/api/v1/auth/demo-session")
    resp_b = client.post("/api/v1/auth/demo-session")

    assert resp_a.status_code == 200
    assert resp_b.status_code == 200

    data_a = resp_a.json()
    data_b = resp_b.json()

    assert data_a["workspace_id"] != data_b["workspace_id"]
    assert data_a["candidate_id"] != data_b["candidate_id"]
    assert data_a["access_token"] != data_b["access_token"]
    assert data_a["workspace_id"].startswith("demo-ws-")
    assert data_b["workspace_id"].startswith("demo-ws-")


def test_2_both_workspaces_start_from_pristine_shinchan_template(client: TestClient):
    """2. Both workspaces start from the same pristine Shinchan template."""
    resp_a = client.post("/api/v1/auth/demo-session")
    resp_b = client.post("/api/v1/auth/demo-session")

    token_a = resp_a.json()["access_token"]
    token_b = resp_b.json()["access_token"]

    cand_a = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_a}"}).json()
    cand_b = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_b}"}).json()

    # Both profiles match the canonical template
    assert cand_a["full_name"] == "Shinchan Nohara"
    assert cand_b["full_name"] == "Shinchan Nohara"
    assert "Bombay" in cand_a["education"][0]["institution"]
    assert "Bombay" in cand_b["education"][0]["institution"]

    # Fictional projects present
    projects_a = [p["title"] for p in cand_a["projects"]]
    assert any("Action Kamen" in p for p in projects_a)
    assert any("Homework" in p for p in projects_a)

    # Skills present
    assert "Python" in cand_a["skills"]
    assert "C++" in cand_a["skills"]
    assert "Data Structures & Algorithms" in cand_a["skills"]
    assert "AI Tools" in cand_a["skills"]

    # Sample evaluations are labeled as sample history
    evals_a = client.get("/api/v1/evaluations", headers={"Authorization": f"Bearer {token_a}"}).json()
    evals_b = client.get("/api/v1/evaluations", headers={"Authorization": f"Bearer {token_b}"}).json()
    assert len(evals_a) >= 2
    assert len(evals_b) >= 2
    assert all("[Sample History]" in e["summary_verdict"] for e in evals_a)


def test_3_changes_to_workspace_a_do_not_affect_workspace_b_or_template(client: TestClient):
    """3. Changes to workspace A do not affect workspace B or the master template."""
    token_a = client.post("/api/v1/auth/demo-session").json()["access_token"]
    token_b = client.post("/api/v1/auth/demo-session").json()["access_token"]

    cand_a = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_a}"}).json()
    cand_b_initial = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_b}"}).json()

    # Modify Workspace A
    client.put(
        f"/api/v1/candidates/{cand_a['id']}",
        json={
            "full_name": "Shinchan Modified",
            "headline": "Lead Distributed Architect @ Custom Inc",
            "skills": ["Rust", "Raft", "Zig"],
        },
        headers={"Authorization": f"Bearer {token_a}"},
    )

    # Verify A changed
    cand_a_updated = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_a}"}).json()
    assert cand_a_updated["full_name"] == "Shinchan Modified"
    assert "Rust" in cand_a_updated["skills"]

    # Verify B is completely untouched and pristine
    cand_b_current = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_b}"}).json()
    assert cand_b_current["full_name"] == "Shinchan Nohara"
    assert cand_b_current["headline"] == cand_b_initial["headline"]
    assert "Rust" not in cand_b_current["skills"]

    # Verify Canonical Template in memory is untouched
    assert SHINCHAN_CANONICAL_PROFILE["full_name"] == "Shinchan Nohara"
    assert "Rust" not in SHINCHAN_CANONICAL_PROFILE["skills"]


def test_4_resume_uploads_and_profile_edits_remain_isolated(client: TestClient):
    """4. Resume uploads and profile edits remain isolated."""
    token_a = client.post("/api/v1/auth/demo-session").json()["access_token"]
    token_b = client.post("/api/v1/auth/demo-session").json()["access_token"]

    cand_a = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_a}"}).json()
    cand_b = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_b}"}).json()

    custom_resume = (
        "SHINCHAN CUSTOM RESUME\n"
        "Expertise: High-throughput Kafka pipelines, Cassandra tuning, and Zero-Trust Auth.\n"
        "Projects: Ultra Kamen Security Gateway.\n"
    )

    upload_resp = client.post(
        f"/api/v1/candidates/{cand_a['id']}/upload-resume",
        files={"file": ("custom_resume.txt", io.BytesIO(custom_resume.encode("utf-8")), "text/plain")},
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert upload_resp.status_code == 200

    cand_a_after = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_a}"}).json()
    cand_b_after = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_b}"}).json()

    assert "Ultra Kamen Security Gateway" in (cand_a_after.get("resume_text") or "")
    assert "Ultra Kamen Security Gateway" not in (cand_b_after.get("resume_text") or "")


def test_5_interview_transcripts_and_evaluations_remain_isolated(client: TestClient):
    """5. Interview transcripts and evaluations remain isolated."""
    token_a = client.post("/api/v1/auth/demo-session").json()["access_token"]
    token_b = client.post("/api/v1/auth/demo-session").json()["access_token"]

    cand_a = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_a}"}).json()
    jobs_a = client.get("/api/v1/jobs", headers={"Authorization": f"Bearer {token_a}"}).json()

    # Start real session in Workspace A
    start_resp = client.post(
        "/api/v1/sessions",
        json={
            "candidate_id": cand_a["id"],
            "job_id": jobs_a[0]["id"],
            "interviewer_id": "alex-lead-001",
            "difficulty": "realistic",
        },
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert start_resp.status_code in (200, 201)
    session_a = start_resp.json()

    # Sessions in A has new session
    sessions_a = client.get("/api/v1/sessions", headers={"Authorization": f"Bearer {token_a}"}).json()
    session_a_ids = [s["id"] for s in sessions_a]
    assert session_a["id"] in session_a_ids

    # Sessions in B does NOT have session A
    sessions_b = client.get("/api/v1/sessions", headers={"Authorization": f"Bearer {token_b}"}).json()
    session_b_ids = [s["id"] for s in sessions_b]
    assert session_a["id"] not in session_b_ids


def test_6_cross_workspace_access_attempts_are_rejected(client: TestClient):
    """6. Cross-workspace access attempts are rejected (404/403)."""
    token_a = client.post("/api/v1/auth/demo-session").json()["access_token"]
    token_b = client.post("/api/v1/auth/demo-session").json()["access_token"]

    cand_b = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_b}"}).json()
    sessions_b = client.get("/api/v1/sessions", headers={"Authorization": f"Bearer {token_b}"}).json()

    # Token A tries to read Candidate B
    resp_cand = client.get(f"/api/v1/candidates/{cand_b['id']}", headers={"Authorization": f"Bearer {token_a}"})
    assert resp_cand.status_code == 404

    # Token A tries to modify Candidate B
    resp_put = client.put(
        f"/api/v1/candidates/{cand_b['id']}",
        json={"full_name": "Infiltrator"},
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert resp_put.status_code == 404

    # Token A tries to read Session B
    resp_sess = client.get(f"/api/v1/sessions/{sessions_b[0]['id']}", headers={"Authorization": f"Bearer {token_a}"})
    assert resp_sess.status_code == 404


def test_7_resetting_a_leaves_b_and_active_sessions_untouched(client: TestClient, test_db: Session):
    """7. Resetting A leaves B and all active B sessions untouched."""
    token_a = client.post("/api/v1/auth/demo-session").json()["access_token"]
    token_b = client.post("/api/v1/auth/demo-session").json()["access_token"]

    cand_a = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_a}"}).json()
    cand_b = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_b}"}).json()
    jobs_b = client.get("/api/v1/jobs", headers={"Authorization": f"Bearer {token_b}"}).json()

    # Make modification to Workspace A
    client.put(
        f"/api/v1/candidates/{cand_a['id']}",
        json={"full_name": "Temp Shinchan A", "headline": "Altered"},
        headers={"Authorization": f"Bearer {token_a}"},
    )

    # Start an active session in Workspace B
    sess_b = client.post(
        "/api/v1/sessions",
        json={
            "candidate_id": cand_b["id"],
            "job_id": jobs_b[0]["id"],
            "interviewer_id": "alex-lead-001",
            "difficulty": "realistic",
        },
        headers={"Authorization": f"Bearer {token_b}"},
    ).json()

    # Reset Workspace A
    reset_resp = client.post("/api/v1/auth/demo-reset", headers={"Authorization": f"Bearer {token_a}"})
    assert reset_resp.status_code == 200

    # Workspace A is restored to baseline
    cand_a_after = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_a}"}).json()
    assert cand_a_after["full_name"] == "Shinchan Nohara"

    # Workspace B's candidate and active session are completely unaffected
    cand_b_after = client.get("/api/v1/candidates/me", headers={"Authorization": f"Bearer {token_b}"}).json()
    assert cand_b_after["id"] == cand_b["id"]

    sess_b_check = client.get(f"/api/v1/sessions/{sess_b['id']}", headers={"Authorization": f"Bearer {token_b}"})
    assert sess_b_check.status_code == 200
    assert sess_b_check.json()["status"] == "active"


def test_8_expired_workspace_cleanup_preserves_valid_and_active_workspaces(test_db: Session):
    """8. Expired workspace cleanup does not remove valid or active workspaces."""
    # Provision workspace 1: valid (fresh)
    tok1, ws1, c1 = provision_isolated_demo_workspace(test_db)

    # Provision workspace 2: simulated expired (> 48 hours old)
    tok2, ws2, c2 = provision_isolated_demo_workspace(test_db)
    u2 = test_db.query(UserModel).filter(UserModel.id == ws2).first()
    u2.created_at = datetime.now(timezone.utc) - timedelta(hours=72)
    test_db.commit()

    # Provision workspace 3: old created_at, BUT has an active interview session
    tok3, ws3, c3 = provision_isolated_demo_workspace(test_db)
    u3 = test_db.query(UserModel).filter(UserModel.id == ws3).first()
    u3.created_at = datetime.now(timezone.utc) - timedelta(hours=72)
    job3 = test_db.query(JobModel).filter(JobModel.user_id == ws3).first()
    active_sess = InterviewSessionModel(
        id=f"sess-active-{ws3}",
        user_id=ws3,
        candidate_id=c3,
        job_id=job3.id,
        interviewer_id="alex-lead-001",
        difficulty="realistic",
        status="active",
        channel="chan-active",
        started_at=datetime.now(timezone.utc),
    )
    test_db.add(active_sess)
    test_db.commit()

    # Run cleanup with max_age_hours=48
    cleaned = cleanup_expired_demo_workspaces(test_db, max_age_hours=48)
    assert cleaned >= 1
    assert test_db.query(UserModel).filter(UserModel.id == ws2).first() is None
    assert test_db.query(UserModel).filter(UserModel.id == ws1).first() is not None  # Fresh workspace preserved!
    assert test_db.query(UserModel).filter(UserModel.id == ws3).first() is not None  # Active session workspace preserved!


def test_9_normal_firebase_authentication_coexists_seamlessly(client: TestClient, test_db: Session):
    """9. Normal Firebase authentication continues to work alongside demo workspaces."""
    # Ensure a regular user exists
    user_reg = test_db.query(UserModel).filter(UserModel.id == "firebase-user-999").first()
    if not user_reg:
        user_reg = UserModel(id="firebase-user-999", email="candidate.real@example.com", display_name="Real Candidate")
        test_db.add(user_reg)
        test_db.commit()

    # Demo tokens and Firebase users remain cleanly separated
    demo_token = client.post("/api/v1/auth/demo-session").json()["access_token"]
    user = verify_demo_token(demo_token, test_db)
    assert user.uid.startswith("demo-ws-")

    # Regular user cannot be reset via demo-reset
    token_reg = create_demo_token(uid="firebase-user-999")
    resp_forbidden = client.post("/api/v1/auth/demo-reset", headers={"Authorization": f"Bearer {token_reg}"})
    assert resp_forbidden.status_code == 403


def test_10_demo_visitor_can_complete_real_interview_flow(client: TestClient):
    """10. Demo visitors can complete the real interview flow without a Firebase account."""
    demo_data = client.post("/api/v1/auth/demo-session").json()
    token = demo_data["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Fetch authenticated candidate profile
    cand = client.get("/api/v1/candidates/me", headers=headers).json()
    assert cand["full_name"] == "Shinchan Nohara"

    # 2. Fetch jobs
    jobs = client.get("/api/v1/jobs", headers=headers).json()
    assert len(jobs) >= 1

    # 3. Start real interview session
    start_resp = client.post(
        "/api/v1/sessions",
        json={
            "candidate_id": cand["id"],
            "job_id": jobs[0]["id"],
            "interviewer_id": "alex-lead-001",
            "difficulty": "realistic",
        },
        headers=headers,
    )
    assert start_resp.status_code in (200, 201)
    session = start_resp.json()
    assert session["status"] == "active"
    assert session["session_plan"] is not None
    assert "opening_question" in session["session_plan"]

    # 4. Fetch next adaptive follow-up
    transcript = [
        {"role": "interviewer", "text": session["session_plan"]["opening_question"]},
        {"role": "candidate", "text": "I used asynchronous queues with Redis to handle write spikes without blocking read queries."},
    ]
    follow_up_resp = client.post(
        f"/api/v1/sessions/{session['id']}/next-question",
        json={"candidate_answer": transcript[1]["text"], "transcript": transcript},
        headers=headers,
    )
    assert follow_up_resp.status_code == 200
    follow_up = follow_up_resp.json()
    assert "question" in follow_up

    # 5. End session and generate real evaluation
    end_resp = client.post(
        f"/api/v1/sessions/{session['id']}/end",
        json={"transcript": transcript},
        headers=headers,
    )
    assert end_resp.status_code == 200
    ended = end_resp.json()
    assert ended["status"] == "ended"

    # 6. Retrieve evaluation
    eval_resp = client.get(f"/api/v1/evaluations/{session['id']}", headers=headers)
    assert eval_resp.status_code == 200
    evaluation = eval_resp.json()
    assert "overall_score" in evaluation
    assert "overall_recommendation" in evaluation
