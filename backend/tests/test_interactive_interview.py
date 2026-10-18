from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.auth import AuthenticatedUser, get_current_user
from app.db.database import Base, get_db
from app.db.models import InterviewEvaluationModel, InterviewSessionModel, UserModel
from app.db.seed_demo_candidate import (
    DEMO_CANDIDATE_ID,
    DEMO_JOB_ID,
    DEMO_USER_ID,
    seed_demo_candidate,
)
from app.db.seed_presets import seed_interviewer_presets
from app.domain.schemas import (
    CompetencyPlanItem,
    DifficultyConfiguration,
    DifficultyMode,
    InterviewSessionPlan,
    InterviewStage,
)
from app.main import app
from app.services.adaptive_orchestrator import AdaptiveInterviewOrchestrator
from app.services.evaluation_engine import EvaluationEngineService


@pytest.fixture
def test_db():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()
    seed_interviewer_presets(db)
    seed_demo_candidate(db, force_reset=False)

    # Add a separate non-demo test user
    db.add(UserModel(id="test-candidate-alice", email="alice@test.com", display_name="Alice Smith"))
    db.commit()

    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def current_user():
    return AuthenticatedUser(uid=DEMO_USER_ID, email="elena.demo@fitcheck.io", display_name="Elena Rostova")


@pytest.fixture
def client(test_db, current_user):
    app.dependency_overrides[get_db] = lambda: test_db
    app.dependency_overrides[get_current_user] = lambda: current_user
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()


def test_candidate_answer_changes_generated_next_turn():
    """Verify that different candidate answers change the generated next interviewer turn dynamically."""
    plan = InterviewSessionPlan(
        difficulty=DifficultyMode.REALISTIC,
        difficulty_config=DifficultyConfiguration(
            difficulty=DifficultyMode.REALISTIC,
            tone="direct, analytical",
            probing_intensity="moderate",
            hint_policy="minimal",
            depth_level="deep",
            expected_evidence_bar="concrete metrics and architecture decisions",
        ),
        competency_plans=[
            CompetencyPlanItem(
                name="Distributed Systems Architecture",
                description="Consensus protocols and fault tolerance",
                target_stage=InterviewStage.TECHNICAL_ASSESSMENT,
                planned_question="How do you architect for horizontal scale and high availability?",
                follow_up_guidance="Probe on consensus and partition handling",
                observable_criteria=["Explains consensus mechanisms", "Handles network partitions gracefully"],
                weight=1.0,
            )
        ],
        opening_question="Welcome to FitCheck. Please introduce yourself and your technical background.",
    )
    orchestrator = AdaptiveInterviewOrchestrator(plan)

    # 1. Candidate answers focusing on Kafka and partition lag
    transcript_kafka = [
        {"role": "interviewer", "text": "How do you handle messaging throughput?", "turn_index": 0},
        {
            "role": "candidate",
            "text": "We partition across Kafka topics and monitor consumer group lag under backpressure.",
            "turn_index": 1,
        },
    ]
    next_q_kafka = orchestrator.select_next_question(transcript_kafka, current_stage=InterviewStage.TECHNICAL_ASSESSMENT)

    # 2. Candidate answers focusing on Postgres indexing and connection pooling
    transcript_postgres = [
        {"role": "interviewer", "text": "How do you handle messaging throughput?", "turn_index": 0},
        {
            "role": "candidate",
            "text": "We rely on Postgres with PgBouncer connection pooling and optimized B-tree composite indices.",
            "turn_index": 1,
        },
    ]
    next_q_postgres = orchestrator.select_next_question(transcript_postgres, current_stage=InterviewStage.TECHNICAL_ASSESSMENT)

    # The generated follow-ups must differ and be contextually grounded in what the candidate said
    assert next_q_kafka.question != next_q_postgres.question
    assert "kafka" in next_q_kafka.question.lower() or "partition" in next_q_kafka.question.lower() or "lag" in next_q_kafka.question.lower()
    assert "postgres" in next_q_postgres.question.lower() or "pooling" in next_q_postgres.question.lower() or "index" in next_q_postgres.question.lower()
    assert next_q_kafka.is_follow_up is True
    assert next_q_postgres.is_follow_up is True


def test_transcript_turns_persisted_to_session_endpoint(client: TestClient, test_db):
    """Verify that calling /sessions/{id}/next-question with candidate answer persists turns to SQLite."""
    # Create a new session with valid preset interviewer 'alex-lead-001'
    resp = client.post(
        "/api/v1/sessions",
        json={
            "candidate_id": DEMO_CANDIDATE_ID,
            "job_id": DEMO_JOB_ID,
            "interviewer_id": "alex-lead-001",
            "difficulty": "challenging",
        },
    )
    assert resp.status_code == 201
    session_data = resp.json()
    session_id = session_data["id"]

    # Post candidate answer to next-question
    candidate_speech = "In our microservices architecture, we implemented Raft consensus with leader leasing to eliminate split-brain."
    next_resp = client.post(
        f"/api/v1/sessions/{session_id}/next-question",
        json={"candidate_answer": candidate_speech},
    )
    assert next_resp.status_code == 200
    next_data = next_resp.json()

    assert "question" in next_data
    assert "transcript" in next_data
    # Both candidate turn and interviewer follow-up must be in the returned transcript
    transcript = next_data["transcript"]
    assert len(transcript) >= 2
    assert any(t["role"] == "candidate" and candidate_speech in t["text"] for t in transcript)
    assert any(t["role"] == "interviewer" and t["text"] == next_data["question"]["question"] for t in transcript)

    # Verify session persisted in the database
    db_session = test_db.query(InterviewSessionModel).filter(InterviewSessionModel.id == session_id).first()
    assert db_session is not None
    assert len(db_session.transcript) >= 2
    assert db_session.transcript[-1]["role"] == "interviewer"


def test_direct_transcript_turn_append_endpoint(client: TestClient, test_db):
    """Verify appending transcript turns directly via POST /sessions/{id}/transcript-turn."""
    resp = client.post(
        "/api/v1/sessions",
        json={
            "candidate_id": DEMO_CANDIDATE_ID,
            "job_id": DEMO_JOB_ID,
            "interviewer_id": "alex-lead-001",
            "difficulty": "realistic",
        },
    )
    assert resp.status_code == 201
    session_id = resp.json()["id"]

    append_resp = client.post(
        f"/api/v1/sessions/{session_id}/transcript-turn",
        json={"role": "candidate", "text": "We deployed Kubernetes with mutual TLS mesh.", "metadata": {"source": "web_speech"}},
    )
    assert append_resp.status_code == 200
    append_data = append_resp.json()
    assert append_data["status"] == "ok"
    assert append_data["turn_count"] == 1

    # Verify DB persistence
    db_session = test_db.query(InterviewSessionModel).filter(InterviewSessionModel.id == session_id).first()
    assert len(db_session.transcript) == 1
    assert db_session.transcript[0]["text"] == "We deployed Kubernetes with mutual TLS mesh."


@pytest.mark.asyncio
async def test_empty_candidate_speech_evaluates_to_truthful_insufficient_evidence():
    """Verify that sessions ending without candidate turns produce an honest Insufficient Evidence evaluation."""
    evaluator = EvaluationEngineService()

    empty_turns = [
        {"turn_index": 0, "speaker": "interviewer", "text": "Hello, welcome to FitCheck."},
        {"turn_index": 1, "speaker": "interviewer", "text": "Can you describe your background?"},
    ]
    rubric = [
        {"name": "Distributed Systems Architecture", "criteria": ["Understands consensus", "Handles partitions"], "weight": 1.0}
    ]

    report = await evaluator.evaluate_interview(
        session_id="empty-sess-1",
        user_id="user-1",
        transcript=empty_turns,
        rubric_competencies=rubric,
    )

    assert report.overall_score == 0.0
    assert report.overall_recommendation == "Insufficient Evidence"
    assert "no candidate verbal responses recorded" in report.summary_verdict.lower()
    for comp in report.competency_scores:
        assert comp["status"] == "insufficient_evidence"


def test_demo_reset_preserves_active_in_flight_sessions(test_db):
    """Verify that resetting the demo candidate does NOT overwrite or wipe active in-flight interview sessions."""
    # Create an active/in_progress session
    active_sess = InterviewSessionModel(
        id="active-user-session-9999",
        user_id=DEMO_USER_ID,
        candidate_id=DEMO_CANDIDATE_ID,
        job_id=DEMO_JOB_ID,
        interviewer_id="alex-lead-001",
        difficulty="realistic",
        status="in_progress",
        channel="fc-active-test",
        transcript=[{"role": "candidate", "text": "I am currently answering an interview question."}],
    )
    test_db.add(active_sess)
    test_db.commit()

    # Trigger demo reset
    seed_demo_candidate(test_db, force_reset=True)

    # Active session must still exist
    recheck = test_db.query(InterviewSessionModel).filter(InterviewSessionModel.id == "active-user-session-9999").first()
    assert recheck is not None
    assert recheck.status == "in_progress"
    assert len(recheck.transcript) == 1


def test_tenant_candidate_isolation_on_session_endpoints(client: TestClient, test_db):
    """Verify that another user's session cannot be read or mutated."""
    # Create session owned by Alice
    alice_sess = InterviewSessionModel(
        id="sess-alice-secret",
        user_id="test-candidate-alice",
        candidate_id="cand-alice",
        job_id=DEMO_JOB_ID,
        interviewer_id="alex-lead-001",
        difficulty="realistic",
        status="in_progress",
        channel="fc-alice-secret",
        session_plan={"session_id": "sess-alice-secret", "job_id": DEMO_JOB_ID, "interviewer_id": "alex-lead-001", "planned_questions": []},
    )
    test_db.add(alice_sess)
    test_db.commit()

    # Current user is Elena (demo user). Attempting to fetch or post to Alice's session returns 404
    resp = client.get("/api/v1/sessions/sess-alice-secret/plan")
    assert resp.status_code == 404

    resp_next = client.post("/api/v1/sessions/sess-alice-secret/next-question", json={"candidate_answer": "Hacking session"})
    assert resp_next.status_code == 404
