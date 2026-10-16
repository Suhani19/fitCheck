from __future__ import annotations

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
    DEFAULT_SIMULATION_DISCLAIMER,
    DifficultyMode,
    InterviewSessionPlan,
    InterviewStage,
)
from app.main import app
from app.services.adaptive_orchestrator import AdaptiveInterviewOrchestrator
from app.services.evaluation_engine import EvaluationEngineService
from app.services.interview_planner import InterviewPlannerService
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

    db.add(UserModel(id="user-orch-1", email="orch1@test.com", display_name="Orch User 1"))
    db.add(UserModel(id="user-orch-2", email="orch2@test.com", display_name="Orch User 2"))
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


def make_user(uid: str):
    return AuthenticatedUser(uid=uid, email=f"{uid}@test.com", display_name=uid)


# Sample candidate and job fixtures
SAMPLE_CANDIDATE = {
    "full_name": "Kavita Raman",
    "headline": "Lead Distributed Systems Engineer",
    "skills": ["Go", "Kafka", "PostgreSQL", "Docker", "Kubernetes"],
    "work_experience": [
        {
            "company": "DataStream Corp",
            "role": "Staff Infrastructure Engineer",
            "start_date": "2021",
            "end_date": "Present",
            "description": "Architected low-latency Kafka ingestion pipelines handling 50k events/sec.",
            "technologies": ["Go", "Kafka", "PostgreSQL"],
        }
    ],
    "projects": [
        {
            "name": "Distributed Lock Manager",
            "description": "Raft-based consensus lock service for microservices.",
            "technologies": ["Go", "gRPC"],
        }
    ],
    "education": [
        {
            "institution": "IIT Madras",
            "degree": "B.Tech",
            "field_of_study": "Computer Science",
            "graduation_year": "2020",
        }
    ],
}

SAMPLE_JOB = {
    "title": "Principal Backend Architect",
    "seniority": "principal",
    "description": "Lead global streaming architecture and disaster recovery strategies.",
    "required_skills": ["Go", "Kafka", "PostgreSQL"],
    "competencies": [
        {
            "name": "High-Throughput Streaming & Partitioning",
            "description": "Mastery of stream processing, partition balancing, and message order guarantees.",
            "criteria": [
                "Articulates partition key hashing strategies for ordered processing.",
                "Explains consumer group rebalancing and offset commit trade-offs.",
            ],
            "weight": 1.5,
        },
        {
            "name": "Fault Tolerance & Disaster Recovery",
            "description": "Mitigating network partitions and node failures.",
            "criteria": [
                "Designs idempotent consumers to prevent duplicate side effects.",
                "Analyzes failover mechanisms under partial network partitions.",
            ],
            "weight": 1.2,
        },
    ],
}

SAMPLE_INTERVIEWER = {
    "name": "Marcus Vance",
    "title": "Principal Distributed Systems Architect",
    "company_context": "High-Throughput Streaming Infrastructure",
    "questioning_style": "challenging",
    "voice_id": "Fenrir",
    "bio": "Specialist in large-scale concurrency and high-availability database architectures.",
}


# ===========================================================================
# 1. Test Each Difficulty Mode
# ===========================================================================


@pytest.mark.asyncio
async def test_four_difficulty_modes_behavior():
    """Verifies that all four difficulty modes produce demonstrably different configurations and question depth."""
    planner = InterviewPlannerService()

    plan_lenient = await planner.generate_plan(
        SAMPLE_CANDIDATE, SAMPLE_JOB, SAMPLE_INTERVIEWER, difficulty=DifficultyMode.LENIENT
    )
    plan_realistic = await planner.generate_plan(
        SAMPLE_CANDIDATE, SAMPLE_JOB, SAMPLE_INTERVIEWER, difficulty=DifficultyMode.REALISTIC
    )
    plan_challenging = await planner.generate_plan(
        SAMPLE_CANDIDATE, SAMPLE_JOB, SAMPLE_INTERVIEWER, difficulty=DifficultyMode.CHALLENGING
    )
    plan_stress = await planner.generate_plan(
        SAMPLE_CANDIDATE, SAMPLE_JOB, SAMPLE_INTERVIEWER, difficulty=DifficultyMode.EXPERT_STRESS
    )

    # 1. Verify distinct difficulty configurations
    assert plan_lenient.difficulty == DifficultyMode.LENIENT
    assert "supportive" in plan_lenient.difficulty_config.tone.lower()
    assert "hints" in plan_lenient.difficulty_config.hint_policy.lower()

    assert plan_realistic.difficulty == DifficultyMode.REALISTIC
    assert "balanced" in plan_realistic.difficulty_config.probing_intensity.lower()

    assert plan_challenging.difficulty == DifficultyMode.CHALLENGING
    assert "deep" in plan_challenging.difficulty_config.probing_intensity.lower()
    assert "no unsolicited hints" in plan_challenging.difficulty_config.hint_policy.lower()

    assert plan_stress.difficulty == DifficultyMode.EXPERT_STRESS
    assert "zero hints" in plan_stress.difficulty_config.hint_policy.lower()
    assert "pressure" in plan_stress.difficulty_config.probing_intensity.lower()

    # 2. Verify questions differ by difficulty
    q_lenient = plan_lenient.competency_plans[0].planned_question
    q_challenging = plan_challenging.competency_plans[0].planned_question
    q_stress = plan_stress.competency_plans[0].planned_question

    assert q_lenient != q_challenging
    assert q_challenging != q_stress
    # Challenging/Stress questions probe deeper architectures or edge cases
    assert len(q_challenging) > 20
    assert len(q_stress) > 20


# ===========================================================================
# 2. Question Relevance to Candidate & Job
# ===========================================================================


@pytest.mark.asyncio
async def test_question_relevance_to_candidate_and_job():
    """Opening question and competency questions must directly reference candidate's projects and job title."""
    planner = InterviewPlannerService()
    plan = await planner.generate_plan(
        SAMPLE_CANDIDATE, SAMPLE_JOB, SAMPLE_INTERVIEWER, difficulty=DifficultyMode.REALISTIC
    )

    # Must reference candidate's verified project "Distributed Lock Manager" or company "DataStream Corp"
    assert ("Distributed Lock Manager" in plan.opening_question) or ("DataStream Corp" in plan.opening_question)
    assert ("Marcus" in plan.opening_question) or ("Marcus Vance" in plan.opening_question)

    # Competency questions must target the job title and streaming competencies
    assert len(plan.competency_plans) == 2
    comp_names = [cp.name for cp in plan.competency_plans]
    assert "High-Throughput Streaming & Partitioning" in comp_names


# ===========================================================================
# 3. Adaptive Follow-ups Based on Prior Answers
# ===========================================================================


@pytest.mark.asyncio
async def test_adaptive_follow_up_selection():
    """Orchestrator must ask grounded follow-ups on candidate's answers and request clarification if vague."""
    planner = InterviewPlannerService()
    plan = await planner.generate_plan(
        SAMPLE_CANDIDATE, SAMPLE_JOB, SAMPLE_INTERVIEWER, difficulty=DifficultyMode.REALISTIC
    )
    orchestrator = AdaptiveInterviewOrchestrator(plan)

    # 1. Candidate mentions Kafka in their answer
    transcript_with_tech = [
        {"role": "interviewer", "text": plan.opening_question, "turn_index": 0},
        {
            "role": "candidate",
            "text": "At DataStream Corp, we adopted Kafka to ingest telemetric data streams and partitioned by customer ID.",
            "turn_index": 1,
        },
    ]

    next_q = orchestrator.select_next_question(transcript_with_tech, current_stage=InterviewStage.EXPERIENCE_DEEP_DIVE)
    assert next_q.is_follow_up is True
    assert "Kafka" in next_q.question
    assert next_q.clarification_needed is False

    # 2. Candidate gives overly brief / vague answer
    transcript_vague = [
        {"role": "interviewer", "text": "Can you explain your database indexing?", "turn_index": 0},
        {"role": "candidate", "text": "It was fast.", "turn_index": 1},
    ]
    clarification_result = orchestrator.select_next_question(
        transcript_vague, current_stage=InterviewStage.EXPERIENCE_DEEP_DIVE
    )
    assert clarification_result.clarification_needed is True
    assert "elaborate" in clarification_result.question.lower() or "role" in clarification_result.question.lower()


# ===========================================================================
# 4. Competency Coverage & Stage Transitions
# ===========================================================================


@pytest.mark.asyncio
async def test_competency_coverage_and_stage_transitions():
    """Verifies that orchestrator accurately tracks evidence turns and triggers stage transitions."""
    planner = InterviewPlannerService()
    plan = await planner.generate_plan(
        SAMPLE_CANDIDATE, SAMPLE_JOB, SAMPLE_INTERVIEWER, difficulty=DifficultyMode.REALISTIC
    )
    orchestrator = AdaptiveInterviewOrchestrator(plan)

    # Start at introduction
    decision_0 = orchestrator.evaluate_stage_transition([], current_stage=InterviewStage.INTRODUCTION)
    assert decision_0.should_transition is False

    # After candidate intro turn -> transitions to experience_deep_dive
    transcript = [
        {"role": "interviewer", "text": "Hello and welcome.", "turn_index": 0},
        {"role": "candidate", "text": "Hi, I am excited to discuss my background.", "turn_index": 1},
    ]
    decision_1 = orchestrator.evaluate_stage_transition(transcript, current_stage=InterviewStage.INTRODUCTION)
    assert decision_1.should_transition is True
    assert decision_1.next_stage == InterviewStage.EXPERIENCE_DEEP_DIVE

    # Add experience turns addressing streaming & partitioning
    transcript.extend([
        {"role": "interviewer", "text": "Tell me about your streaming pipeline.", "turn_index": 2},
        {
            "role": "candidate",
            "text": "We designed custom partition key hashing algorithms to ensure message order guarantees per customer.",
            "turn_index": 3,
        },
        {"role": "interviewer", "text": "How did you prevent consumer group lag?", "turn_index": 4},
        {
            "role": "candidate",
            "text": "We tuned consumer group rebalancing and batch size, monitoring offset commit latency.",
            "turn_index": 5,
        },
    ])

    coverage = orchestrator.track_competency_coverage(transcript)
    assert coverage["High-Throughput Streaming & Partitioning"].status in ("in_progress", "covered")
    assert coverage["High-Throughput Streaming & Partitioning"].evidence_count >= 1

    # Transition to technical assessment
    decision_2 = orchestrator.evaluate_stage_transition(transcript, current_stage=InterviewStage.EXPERIENCE_DEEP_DIVE)
    assert decision_2.should_transition is True
    assert decision_2.next_stage == InterviewStage.TECHNICAL_ASSESSMENT


# ===========================================================================
# 5. Duplicate Question Prevention
# ===========================================================================


def test_duplicate_question_prevention():
    """Orchestrator must detect and prevent identical or semantically repetitive questions."""
    plan = InterviewSessionPlan(
        difficulty=DifficultyMode.REALISTIC,
        difficulty_config=InterviewPlannerService().get_difficulty_config(DifficultyMode.REALISTIC),
        opening_question="Welcome, tell me about your background.",
    )
    orchestrator = AdaptiveInterviewOrchestrator(plan)

    past_questions = [
        "Could you walk me through your Kafka partition key hashing strategy?",
        "What was the most challenging production bug you encountered?",
    ]

    # Exact or near-identical question
    duplicate_q = "Could you walk me through your Kafka partition key hashing strategy in detail?"
    assert orchestrator._is_duplicate_question(duplicate_q, past_questions) is True

    # Entirely different question
    new_q = "How do you handle database migration rollbacks in zero-downtime environments?"
    assert orchestrator._is_duplicate_question(new_q, past_questions) is False


# ===========================================================================
# 6. Invalid or Unavailable Model Responses
# ===========================================================================


@pytest.mark.asyncio
async def test_invalid_or_offline_model_fallback():
    """Planning and evaluation services must fall back gracefully when Gemini is unavailable or malformed."""
    # 1. Mock Gemini throwing connection error in planner
    planner = InterviewPlannerService(api_key="mock_key")
    planner.client = MagicMock()
    planner.client.aio.models.generate_content = AsyncMock(side_effect=RuntimeError("503 Service Unavailable"))

    plan = await planner.generate_plan(SAMPLE_CANDIDATE, SAMPLE_JOB, SAMPLE_INTERVIEWER)
    assert plan is not None
    assert len(plan.competency_plans) >= 2
    assert plan.opening_question is not None

    # 2. Mock Gemini throwing error in evaluator
    evaluator = EvaluationEngineService(api_key="mock_key")
    evaluator.client = MagicMock()
    evaluator.client.aio.models.generate_content = AsyncMock(side_effect=RuntimeError("JSON Decode Error"))

    sample_transcript = [
        {"role": "interviewer", "text": "Explain Kafka partitioning.", "turn_index": 0},
        {"role": "candidate", "text": "We hashed customer IDs to maintain strict message ordering.", "turn_index": 1},
    ]
    report = await evaluator.evaluate_interview(
        session_id="test-sess-fallback",
        user_id="user-orch-1",
        transcript=sample_transcript,
        rubric_competencies=SAMPLE_JOB["competencies"],
    )
    assert report is not None
    assert report.overall_score >= 1.0
    assert len(report.competency_scores) == 2


# ===========================================================================
# 7. Evidence Quotation and Transcript-Turn Validation
# ===========================================================================


def test_transcript_quotation_verification():
    """Evaluator must verify that quotations strictly match actual candidate statements."""
    evaluator = EvaluationEngineService()

    clean_turns = [
        {"turn_index": 0, "speaker": "interviewer", "text": "How do you prevent duplicate side effects?"},
        {
            "turn_index": 1,
            "speaker": "candidate",
            "text": "We designed idempotent consumers utilizing PostgreSQL unique constraints.",
        },
    ]

    competency_scores = [
        {
            "competency_name": "Fault Tolerance",
            "evidence_citations": [
                # Valid citation matching candidate turn 1
                {
                    "quote": "designed idempotent consumers utilizing PostgreSQL unique constraints",
                    "turn_index": 1,
                    "speaker": "candidate",
                    "relevance": "Direct evidence of idempotency",
                },
                # Hallucinated quote never spoken by candidate
                {
                    "quote": "We implemented quantum distributed consensus",
                    "turn_index": 1,
                    "speaker": "candidate",
                    "relevance": "Fabricated claim",
                },
            ],
        }
    ]

    evaluator._verify_evidence_citations(competency_scores, clean_turns)

    citations = competency_scores[0]["evidence_citations"]
    assert citations[0]["verified"] is True
    assert citations[1]["verified"] is False
    assert "[Unverified citation]" in citations[1]["quote"]


# ===========================================================================
# 8. Insufficient Evidence vs Demonstrated Competency Gaps
# ===========================================================================


@pytest.mark.asyncio
async def test_insufficient_evidence_vs_demonstrated_gaps():
    """Unexplored competencies must be classified as insufficient evidence, not penalized as demonstrated gaps."""
    evaluator = EvaluationEngineService()

    # Candidate only discusses streaming; disaster recovery is never reached
    partial_transcript = [
        {"role": "interviewer", "text": "Tell me about partitioning.", "turn_index": 0},
        {"role": "candidate", "text": "We used partition hashing for ordered message streams.", "turn_index": 1},
    ]

    report = await evaluator.evaluate_interview(
        session_id="sess-partial",
        user_id="user-orch-1",
        transcript=partial_transcript,
        rubric_competencies=SAMPLE_JOB["competencies"],
    )

    scores_by_name = {cs["competency_name"]: cs for cs in report.competency_scores}

    # Streaming was evaluated with evidence
    assert scores_by_name["High-Throughput Streaming & Partitioning"]["status"] == "evaluated"

    # Fault Tolerance was never discussed -> marked as insufficient_evidence
    fault_tol = scores_by_name["Fault Tolerance & Disaster Recovery"]
    assert fault_tol["status"] == "insufficient_evidence"

    # Must be recorded under insufficient_evidence, NOT in technical_gaps
    assert any("Fault Tolerance" in s for s in report.insufficient_evidence)
    assert not any("Fault Tolerance" in g for g in report.technical_gaps)


# ===========================================================================
# 9. Session Recovery & Interrupted Interviews
# ===========================================================================


def test_session_lifecycle_and_interruption_recovery(client):
    """Verifies that interview session can be created, inspected, recovered, and concluded after interruption."""
    app.dependency_overrides[get_current_user] = lambda: make_user("user-orch-1")

    # 1. Create candidate and job
    cand_resp = client.post("/api/v1/candidates", json=SAMPLE_CANDIDATE)
    assert cand_resp.status_code == 201
    cand_id = cand_resp.json()["id"]

    job_resp = client.post("/api/v1/jobs", json=SAMPLE_JOB)
    assert job_resp.status_code == 201
    job_id = job_resp.json()["id"]

    # 2. Create session with realistic difficulty
    session_payload = {
        "candidate_id": cand_id,
        "job_id": job_id,
        "interviewer_id": "marcus-arch-001",
        "difficulty": "realistic",
    }
    sess_resp = client.post("/api/v1/sessions", json=session_payload)
    assert sess_resp.status_code == 201
    sess_id = sess_resp.json()["id"]
    assert sess_resp.json()["status"] == "active"
    assert sess_resp.json()["session_plan"] is not None

    # 3. Retrieve session plan via /sessions/{id}/plan
    plan_resp = client.get(f"/api/v1/sessions/{sess_id}/plan")
    assert plan_resp.status_code == 200
    assert plan_resp.json()["difficulty"] == "realistic"

    # 4. Check next-question endpoint
    next_q_resp = client.post(f"/api/v1/sessions/{sess_id}/next-question")
    assert next_q_resp.status_code == 200
    assert "question" in next_q_resp.json()

    # 5. Simulate interview interruption: end session with partial transcript turns
    partial_transcript = [
        {"role": "interviewer", "text": "Welcome to the interview.", "turn_index": 0},
        {"role": "candidate", "text": "Thank you, I built Kafka streaming pipelines at DataStream Corp.", "turn_index": 1},
    ]
    end_resp = client.post(
        f"/api/v1/sessions/{sess_id}/end",
        json={"transcript": partial_transcript},
    )
    assert end_resp.status_code == 200
    assert end_resp.json()["status"] == "ended"

    # 6. Verify evaluation was automatically persisted and accessible
    eval_resp = client.get(f"/api/v1/evaluations/{sess_id}")
    assert eval_resp.status_code == 200
    eval_data = eval_resp.json()
    assert eval_data["session_id"] == sess_id
    assert eval_data["overall_score"] >= 1.0


# ===========================================================================
# 10. Cross-User Data Isolation
# ===========================================================================


def test_cross_user_session_and_plan_isolation(client):
    """User 2 must be strictly forbidden from viewing User 1's session, plan, next question, or evaluation."""
    # User 1 creates candidate, job, session
    app.dependency_overrides[get_current_user] = lambda: make_user("user-orch-1")

    cand_id = client.post("/api/v1/candidates", json=SAMPLE_CANDIDATE).json()["id"]
    job_id = client.post("/api/v1/jobs", json=SAMPLE_JOB).json()["id"]

    sess_resp = client.post(
        "/api/v1/sessions",
        json={
            "candidate_id": cand_id,
            "job_id": job_id,
            "interviewer_id": "sarah-em-001",
            "difficulty": "challenging",
        },
    )
    sess_id = sess_resp.json()["id"]

    # Switch to User 2
    app.dependency_overrides[get_current_user] = lambda: make_user("user-orch-2")

    # Get session -> 404
    assert client.get(f"/api/v1/sessions/{sess_id}").status_code == 404

    # Get session plan -> 404
    assert client.get(f"/api/v1/sessions/{sess_id}/plan").status_code == 404

    # Get next question -> 404
    assert client.post(f"/api/v1/sessions/{sess_id}/next-question").status_code == 404

    # End session -> 404
    assert client.post(f"/api/v1/sessions/{sess_id}/end", json={"transcript": []}).status_code == 404

    # Get evaluation -> 404
    assert client.get(f"/api/v1/evaluations/{sess_id}").status_code == 404
