from __future__ import annotations

import os
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.auth import AuthenticatedUser, get_current_user
from app.db.database import Base, get_db
from app.db.models import UserModel
from app.db.seed_presets import seed_interviewer_presets
from app.domain.schemas import (
    CandidateCreateRequest,
    DifficultyMode,
    EndInterviewSessionRequest,
    InterviewSessionCreateRequest,
    InterviewSessionPlan,
    JobCreateRequest,
)
from app.main import app
from app.repositories.sql_fitcheck import (
    SQLCandidateRepository,
    SQLEvaluationRepository,
    SQLInterviewSessionRepository,
    SQLJobRepository,
)
from app.services.runtime_orchestrator import FitCheckRuntimeService


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

    db.add(UserModel(id="alice-uid", email="alice@test.com", display_name="Alice User"))
    db.add(UserModel(id="bob-uid", email="bob@test.com", display_name="Bob User"))
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


def make_auth_headers(uid: str) -> dict[str, str]:
    return {"Authorization": f"Bearer mock_token_for_{uid}"}


def setup_candidate_and_job(db, user_id: str):
    cand_repo = SQLCandidateRepository(db)
    cand = cand_repo.create(
        user_id=user_id,
        candidate_data={
            "full_name": "Kavita Raman",
            "headline": "Lead Distributed Systems Engineer",
            "skills": ["Go", "Kafka", "PostgreSQL"],
            "work_experience": [{"company": "DataStream Corp", "role": "Staff Engineer"}],
            "projects": [{"name": "Distributed Lock Manager", "description": "Raft lock service"}],
        },
    )

    job_repo = SQLJobRepository(db)
    job = job_repo.create(
        user_id=user_id,
        job_data={
            "title": "Principal Architect",
            "seniority": "principal",
            "description": "Lead global streaming architecture.",
            "required_skills": ["Go", "Kafka"],
            "competencies": [
                {
                    "name": "High-Throughput Streaming",
                    "description": "Partitioning and guarantees",
                    "criteria": ["Partition key design", "Consumer rebalancing"],
                    "weight": 1.5,
                }
            ],
        },
    )
    return cand, job


# ===========================================================================
# 1. Full Live Lifecycle: Create -> Provision -> Next-Question -> End -> Persist
# ===========================================================================


def test_full_session_lifecycle_with_isolated_persistence(client, test_db_session):
    """Traces complete session creation, adaptive follow-ups, end session, transcript recovery, and evaluation ownership."""
    cand, job = setup_candidate_and_job(test_db_session, "alice-uid")

    def mock_get_current_user_alice():
        return AuthenticatedUser(uid="alice-uid", email="alice@test.com", display_name="Alice")

    app.dependency_overrides[get_current_user] = mock_get_current_user_alice

    # 1. Create session (Mocked Agora/Gemini Live to isolate test from network costs)
    create_payload = {
        "candidate_id": cand.id,
        "job_id": job.id,
        "interviewer_id": "marcus-arch-001",
        "difficulty": "realistic",
    }
    create_resp = client.post("/api/v1/sessions", json=create_payload)
    assert create_resp.status_code == 201, create_resp.text
    session_data = create_resp.json()
    session_id = session_data["id"]
    assert session_data["status"] == "active"
    assert session_data["channel"] == f"fitcheck-{session_id}"
    assert session_data["session_plan"] is not None
    assert any(
        "High-Throughput Streaming" in cp["name"]
        for cp in session_data["session_plan"]["competency_plans"]
    )

    # 2. Check Plan retrieval
    plan_resp = client.get(f"/api/v1/sessions/{session_id}/plan")
    assert plan_resp.status_code == 200
    assert plan_resp.json()["difficulty"] == "realistic"

    # 3. Simulate ongoing conversation & adaptive follow-up
    sess_repo = SQLInterviewSessionRepository(test_db_session)
    sess_repo.update_transcript(
        session_id,
        "alice-uid",
        [
            {"role": "interviewer", "text": "Walk me through Kafka partitioning.", "turn_index": 0},
            {"role": "candidate", "text": "At DataStream Corp, we partitioned by customer ID with murmur3.", "turn_index": 1},
        ],
    )

    next_q_resp = client.post(f"/api/v1/sessions/{session_id}/next-question")
    assert next_q_resp.status_code == 200
    next_q_data = next_q_resp.json()
    assert "question" in next_q_data
    assert "competency_coverage" in next_q_data

    # 4. End session and verify evaluation persistence
    transcript = [
        {"role": "interviewer", "text": "Walk me through Kafka partitioning.", "turn_index": 0},
        {"role": "candidate", "text": "At DataStream Corp, we partitioned by customer ID with murmur3 to maintain per-customer order.", "turn_index": 1},
        {"role": "interviewer", "text": "How did you handle consumer rebalances?", "turn_index": 2},
        {"role": "candidate", "text": "We adopted cooperative sticky assignors to prevent stop-the-world pauses.", "turn_index": 3},
    ]

    end_resp = client.post(
        f"/api/v1/sessions/{session_id}/end",
        json={"transcript": transcript},
    )
    assert end_resp.status_code == 200
    ended_session = end_resp.json()
    assert ended_session["status"] == "ended"
    assert ended_session["ended_at"] is not None

    # Verify transcript persisted in DB
    db_session = sess_repo.get(session_id, "alice-uid")
    assert db_session is not None
    assert len(db_session.transcript) == 4

    # 5. Verify Evaluation Record and Ownership
    eval_resp = client.get(f"/api/v1/evaluations/{session_id}")
    assert eval_resp.status_code == 200
    eval_data = eval_resp.json()
    assert eval_data["session_id"] == session_id
    assert eval_data["user_id"] == "alice-uid"
    assert eval_data["overall_score"] >= 1.0
    assert eval_data["overall_recommendation"] in ["Strong Hire", "Hire", "Leaning Hire", "Leaning No Hire", "No Hire", "Insufficient Signal"]
    assert len(eval_data["competency_scores"]) >= 1

    # 6. Verify Idempotent Repeated End Session Calls
    app.dependency_overrides[get_current_user] = mock_get_current_user_alice
    repeated_end_resp = client.post(
        f"/api/v1/sessions/{session_id}/end",
        json={"transcript": transcript},
    )
    assert repeated_end_resp.status_code == 200
    assert repeated_end_resp.json()["status"] == "ended"

    eval_resp_2 = client.get(f"/api/v1/evaluations/{session_id}")
    assert eval_resp_2.status_code == 200
    assert eval_resp_2.json()["id"] == eval_data["id"]

    # 7. Verify Bob cannot access Alice's session or evaluation
    def mock_get_current_user_bob():
        return AuthenticatedUser(uid="bob-uid", email="bob@test.com", display_name="Bob")

    app.dependency_overrides[get_current_user] = mock_get_current_user_bob

    bob_sess_resp = client.get(f"/api/v1/sessions/{session_id}")
    assert bob_sess_resp.status_code == 404

    bob_eval_resp = client.get(f"/api/v1/evaluations/{session_id}")
    assert bob_eval_resp.status_code == 404

    bob_plan_resp = client.get(f"/api/v1/sessions/{session_id}/plan")
    assert bob_plan_resp.status_code == 404


# ===========================================================================
# 2. Failure Paths, Agora History Fallback, and Cleanup
# ===========================================================================


def test_session_creation_fails_when_cross_tenant_resources_used(client, test_db_session):
    """Rejects session creation when referencing candidate or job owned by another user."""
    cand_alice, job_alice = setup_candidate_and_job(test_db_session, "alice-uid")

    def mock_get_current_user_bob():
        return AuthenticatedUser(uid="bob-uid", email="bob@test.com", display_name="Bob")

    app.dependency_overrides[get_current_user] = mock_get_current_user_bob

    # Bob attempts to start interview with Alice's candidate
    resp = client.post(
        "/api/v1/sessions",
        json={
            "candidate_id": cand_alice.id,
            "job_id": job_alice.id,
            "interviewer_id": "interviewer-marcus",
            "difficulty": "realistic",
        },
    )
    assert resp.status_code == 404
    assert "not found" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_end_session_recovers_transcript_from_agora_agent_history():
    """When client sends empty transcript, runtime falls back to querying Agora Cloud Agent history."""
    runtime_svc = FitCheckRuntimeService()

    mock_history_item = MagicMock()
    mock_history_item.content = "I redesigned our Kafka pipeline to prevent rebalance spikes."
    mock_history_item.role = "user"

    mock_history_resp = MagicMock()
    mock_history_resp.contents = [mock_history_item]

    with patch("app.services.runtime_orchestrator.AgoraService") as MockAgoraSvc:
        instance = MockAgoraSvc.return_value
        instance.app_id = "test_app_id"
        instance.client.agents.get_history.return_value = mock_history_resp

        evaluation = await runtime_svc.end_session_and_evaluate(
            session_id="session-fallback-1",
            user_id="alice-uid",
            transcript=[],  # Empty client transcript
            rubric_competencies=[{"name": "Streaming Architecture", "criteria": ["Scaling pipelines"]}],
            difficulty=DifficultyMode.REALISTIC,
            agent_id="agora-agent-999",
        )

        assert evaluation is not None
        assert evaluation.session_id == "session-fallback-1"
        assert evaluation.user_id == "alice-uid"
        # Agora get_history should have been called
        instance.client.agents.get_history.assert_called_once_with(
            appid="test_app_id",
            agent_id="agora-agent-999",
        )
