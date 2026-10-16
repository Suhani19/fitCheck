from __future__ import annotations

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.auth import AuthenticatedUser, get_current_user
from app.db.database import Base, get_db
from app.db.models import UserModel
from app.db.seed_presets import seed_interviewer_presets
from app.domain.schemas import DifficultyMode, InterviewSessionPlan, PlanStrategy
from app.main import app
from app.repositories.sql_fitcheck import (
    SQLCandidateRepository,
    SQLInterviewerRepository,
    SQLJobRepository,
)
from app.services.runtime_orchestrator import FitCheckRuntimeService


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

    db.add(UserModel(id="cand-user-1", email="candidate@fitcheck.io", display_name="Candidate One"))
    db.commit()

    # Create default job for foreign key
    job_repo = SQLJobRepository(db)
    job_repo.create(
        user_id="cand-user-1",
        job_data={
            "id": "job-dist-sys",
            "title": "Staff Distributed Systems Engineer",
            "seniority": "staff",
            "description": "Distributed systems role.",
            "required_skills": ["Raft", "Go"],
        },
    )

    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def auth_client(test_db):
    def override_get_db():
        yield test_db

    def override_get_current_user():
        return AuthenticatedUser(uid="cand-user-1", email="candidate@fitcheck.io", display_name="Candidate One")

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user] = override_get_current_user

    with TestClient(app) as c:
        yield c

    app.dependency_overrides.clear()


def test_seed_presets_and_retrieval(test_db):
    repo = SQLInterviewerRepository(test_db)
    presets = repo.list("cand-user-1")
    preset_ids = {p.id for p in presets}
    assert "sarah-em-001" in preset_ids
    assert "marcus-arch-001" in preset_ids
    assert "alex-lead-001" in preset_ids

    sarah = repo.get("sarah-em-001")
    assert sarah is not None
    assert sarah.name == "Sarah Chen"
    assert sarah.voice_id == "Aoede"

    marcus = repo.get("marcus-arch-001")
    assert marcus is not None
    assert marcus.name == "Marcus Vance"
    assert marcus.voice_id == "Fenrir"

    alex = repo.get("alex-lead-001")
    assert alex is not None
    assert alex.name == "Alex Rivera"
    assert alex.voice_id == "Puck"


def test_legacy_alias_resolution(test_db):
    repo = SQLInterviewerRepository(test_db)
    legacy_marcus = repo.get("int-marcus")
    assert legacy_marcus is not None
    assert legacy_marcus.id == "marcus-arch-001"

    legacy_sarah = repo.get("int-sarah")
    assert legacy_sarah is not None
    assert legacy_sarah.id == "sarah-em-001"

    legacy_alex = repo.get("int-alex")
    assert legacy_alex is not None
    assert legacy_alex.id == "alex-lead-001"


def test_session_creation_with_specific_interviewers(auth_client, test_db):
    cand_repo = SQLCandidateRepository(test_db)
    cand = cand_repo.create(
        user_id="cand-user-1",
        candidate_data={
            "full_name": "Candidate One",
            "headline": "Full Stack Engineer",
            "skills": ["React", "TypeScript", "Python"],
        },
    )

    # 1. Create session with Alex Rivera
    alex_resp = auth_client.post("/api/v1/sessions", json={
        "candidate_id": cand.id,
        "interviewer_id": "alex-lead-001",
        "job_id": "job-dist-sys",
        "difficulty": "realistic",
    })
    assert alex_resp.status_code == 201
    alex_sess = alex_resp.json()
    assert alex_sess["interviewer_id"] == "alex-lead-001"
    assert alex_sess["difficulty"] == "realistic"

    # 2. Create session with Sarah Chen
    sarah_resp = auth_client.post("/api/v1/sessions", json={
        "candidate_id": cand.id,
        "interviewer_id": "sarah-em-001",
        "job_id": "job-dist-sys",
        "difficulty": "challenging",
    })
    assert sarah_resp.status_code == 201
    sarah_sess = sarah_resp.json()
    assert sarah_sess["interviewer_id"] == "sarah-em-001"
    assert sarah_sess["difficulty"] == "challenging"


def test_general_practice_without_job_description(auth_client, test_db):
    cand_repo = SQLCandidateRepository(test_db)
    cand = cand_repo.create(
        user_id="cand-user-1",
        candidate_data={
            "full_name": "Candidate One",
            "headline": "General Practice Candidate",
            "skills": ["Algorithms", "System Design"],
        },
    )

    # Use general-practice as job_id
    resp = auth_client.post("/api/v1/sessions", json={
        "candidate_id": cand.id,
        "interviewer_id": "alex-lead-001",
        "job_id": "general-practice",
        "difficulty": "lenient",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["interviewer_id"] == "alex-lead-001"
    assert data["job_id"] == "general-practice"
    assert data["difficulty"] == "lenient"


def test_explicit_404_when_interviewer_not_found(auth_client, test_db):
    cand_repo = SQLCandidateRepository(test_db)
    cand = cand_repo.create(
        user_id="cand-user-1",
        candidate_data={
            "full_name": "Candidate One",
            "headline": "Engineer",
            "skills": ["Python"],
        },
    )

    resp = auth_client.post("/api/v1/sessions", json={
        "candidate_id": cand.id,
        "interviewer_id": "non-existent-interviewer-999",
        "job_id": "job-dist-sys",
        "difficulty": "realistic",
    })
    assert resp.status_code == 404
    detail = resp.json()["detail"]
    assert "Interviewer 'non-existent-interviewer-999' not found" in detail


def test_runtime_prompt_and_voice_persona_isolation():
    runtime = FitCheckRuntimeService()

    # Sarah Chen (EM, Aoede voice)
    sarah_data = {
        "id": "sarah-em-001",
        "name": "Sarah Chen",
        "title": "Senior Engineering Manager",
        "company_context": "Uber Core Infra",
        "questioning_style": "rigorous",
        "voice_id": "Aoede",
    }
    sarah_plan = InterviewSessionPlan(
        difficulty="realistic",
        difficulty_config=runtime.planner.get_difficulty_config("realistic"),
        opening_question="Hello, let's begin.",
    )
    sarah_prompt = runtime.compile_runtime_prompt(
        interviewer_data=sarah_data,
        job_data={"title": "Staff Infrastructure Engineer", "required_skills": ["Reliability", "Kubernetes"]},
        candidate_data={"full_name": "Elena Rostova", "headline": "Staff Systems Eng"},
        session_plan=sarah_plan,
    )
    assert "Sarah Chen" in sarah_prompt
    assert "Senior Engineering Manager" in sarah_prompt
    assert "Uber Core Infra" in sarah_prompt

    # Alex Rivera (Full-Stack, Puck voice)
    alex_data = {
        "id": "alex-lead-001",
        "name": "Alex Rivera",
        "title": "Staff Full-Stack Product Engineer",
        "company_context": "Vercel / Next.js",
        "questioning_style": "conversational",
        "voice_id": "Puck",
    }
    alex_plan = InterviewSessionPlan(
        difficulty="challenging",
        difficulty_config=runtime.planner.get_difficulty_config("challenging"),
        opening_question="Hello, let's begin.",
    )
    alex_prompt = runtime.compile_runtime_prompt(
        interviewer_data=alex_data,
        job_data={"title": "Senior Frontend Engineer", "required_skills": ["React", "State Management"]},
        candidate_data={"full_name": "Elena Rostova", "headline": "Staff Systems Eng"},
        session_plan=alex_plan,
    )
    assert "Alex Rivera" in alex_prompt
    assert "Staff Full-Stack Product Engineer" in alex_prompt
    assert "Vercel / Next.js" in alex_prompt


def test_difficulty_does_not_change_interviewer_identity():
    runtime = FitCheckRuntimeService()
    alex_data = {
        "id": "alex-lead-001",
        "name": "Alex Rivera",
        "title": "Staff Full-Stack Product Engineer",
        "company_context": "Vercel / Next.js",
        "questioning_style": "conversational",
        "voice_id": "Puck",
    }
    plan_lenient = InterviewSessionPlan(
        difficulty="lenient",
        difficulty_config=runtime.planner.get_difficulty_config("lenient"),
        opening_question="Hello, let's begin.",
    )
    plan_stress = InterviewSessionPlan(
        difficulty="expert_stress",
        difficulty_config=runtime.planner.get_difficulty_config("expert_stress"),
        opening_question="Hello, let's begin.",
    )
    prompt_lenient = runtime.compile_runtime_prompt(
        interviewer_data=alex_data,
        job_data={"title": "Full Stack Dev"},
        candidate_data={"full_name": "Elena Rostova"},
        session_plan=plan_lenient,
    )
    prompt_stress = runtime.compile_runtime_prompt(
        interviewer_data=alex_data,
        job_data={"title": "Full Stack Dev"},
        candidate_data={"full_name": "Elena Rostova"},
        session_plan=plan_stress,
    )
    # Both must identify as Alex Rivera
    assert "Alex Rivera" in prompt_lenient
    assert "Alex Rivera" in prompt_stress
    # Difficulty guidelines differ
    assert "lenient" in prompt_lenient.lower() or "supportive" in prompt_lenient.lower() or "encouraging" in prompt_lenient.lower()
    assert "stress" in prompt_stress.lower() or "demanding" in prompt_stress.lower() or "relentless" in prompt_stress.lower()
