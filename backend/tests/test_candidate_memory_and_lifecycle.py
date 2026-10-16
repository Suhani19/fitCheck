"""
Comprehensive integration tests for:
1. Candidate Memory Privacy & Lifecycle (Inspection, Isolation, Deletion, Purge)
2. Memory Reuse Across Sessions (Extraction -> Persistence -> Retrieval in Prompt -> Isolation -> Deletion Effect)
3. Interview Data Lifecycle Edge Cases (Empty transcripts, Idempotent Duplicate End, Interrupted Session)
"""
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
from app.domain.schemas import DifficultyMode, InterviewSessionPlan
from app.main import app
from app.repositories.sql_fitcheck import (
    SQLCandidateMemoryRepository,
    SQLCandidateRepository,
    SQLEvaluationRepository,
    SQLInterviewSessionRepository,
    SQLJobRepository,
)
from app.services.interview_planner import InterviewPlannerService
from app.services.runtime_orchestrator import FitCheckRuntimeService


@pytest.fixture
def test_db_session():
    """Isolated in-memory SQLite database supporting all models including candidate_practice_memories."""
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()
    seed_interviewer_presets(db)

    # Seed users
    db.add(UserModel(id="alice-uid", email="alice@test.com", display_name="Alice Candidate"))
    db.add(UserModel(id="bob-uid", email="bob@test.com", display_name="Bob Attacker"))
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


def setup_candidate_and_job(db, user_id: str):
    cand_repo = SQLCandidateRepository(db)
    cand = cand_repo.create(
        user_id=user_id,
        candidate_data={
            "full_name": "Alice Candidate",
            "headline": "Senior Backend Systems Engineer",
            "skills": ["Go", "Raft", "PostgreSQL"],
            "work_experience": [{"company": "StreamCo", "role": "Senior Engineer"}],
            "projects": [{"name": "Raft Consensus Lock", "description": "Distributed lock manager"}],
        },
    )

    job_repo = SQLJobRepository(db)
    job = job_repo.create(
        user_id=user_id,
        job_data={
            "title": "Principal Systems Engineer",
            "seniority": "Principal",
            "description": "Architect distributed consensus services.",
            "required_skills": ["Go", "Raft"],
            "competencies": [
                {
                    "name": "Consensus Protocols",
                    "description": "Leader election and log replication",
                    "criteria": ["Quorum calculation", "Split-brain recovery"],
                    "weight": 1.0,
                }
            ],
        },
    )
    return cand, job


# ===========================================================================
# 1. Candidate Memory Inspection, Isolation & Privacy Controls
# ===========================================================================

def test_candidate_memory_privacy_and_isolation(client, test_db_session):
    """Verifies that candidates can inspect and delete their own memories, while
    other candidates cannot read or delete them, and internal system IDs are not leaked."""
    mem_repo = SQLCandidateMemoryRepository(test_db_session)
    
    # Create memories for Alice using dictionary payload
    mem1 = mem_repo.create(
        user_id="alice-uid",
        memory_data={
            "content": "Candidate built a distributed log replicator in Go.",
            "category": "fact",
            "importance": 0.9,
        },
    )
    mem2 = mem_repo.create(
        user_id="alice-uid",
        memory_data={
            "content": "Candidate prefers Go concurrency over thread pools.",
            "category": "preference",
            "importance": 0.7,
        },
    )
    
    # Create memory for Bob
    mem_bob = mem_repo.create(
        user_id="bob-uid",
        memory_data={
            "content": "Bob has 2 years of Java experience.",
            "category": "fact",
            "importance": 0.5,
        },
    )

    # 1. Unauthenticated request rejected
    app.dependency_overrides.pop(get_current_user, None)
    unauth_resp = client.get("/api/v1/candidate/memories")
    assert unauth_resp.status_code == 401

    # 2. Alice inspects her memories
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        uid="alice-uid", email="alice@test.com", display_name="Alice"
    )
    alice_resp = client.get("/api/v1/candidate/memories")
    assert alice_resp.status_code == 200
    alice_mems = alice_resp.json()
    assert len(alice_mems) == 2
    
    # Privacy check: Verify schema fields exposed vs hidden
    # Only id, content, category, importance, created_at should be returned
    sample = alice_mems[0]
    assert "id" in sample
    assert "content" in sample
    assert "category" in sample
    assert "importance" in sample
    assert "created_at" in sample
    # Ensure internal character IDs or raw user IDs are not leaked in response
    assert "character_id" not in sample
    assert "user_id" not in sample

    # 3. Bob inspects his memories (Isolation check)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        uid="bob-uid", email="bob@test.com", display_name="Bob"
    )
    bob_resp = client.get("/api/v1/candidate/memories")
    assert bob_resp.status_code == 200
    bob_mems = bob_resp.json()
    assert len(bob_mems) == 1
    assert bob_mems[0]["id"] == mem_bob.id
    assert not any(m["id"] in [mem1.id, mem2.id] for m in bob_mems)

    # 4. Bob attempts to delete Alice's memory (Authorization & Isolation check)
    bob_del_resp = client.delete(f"/api/v1/candidate/memories/{mem1.id}")
    assert bob_del_resp.status_code == 404, "Attacker should receive 404 when attempting to delete another user's memory"

    # Verify Alice's memory was NOT deleted
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        uid="alice-uid", email="alice@test.com", display_name="Alice"
    )
    alice_resp_after = client.get("/api/v1/candidate/memories")
    assert len(alice_resp_after.json()) == 2

    # 5. Alice deletes one of her memories
    del_resp = client.delete(f"/api/v1/candidate/memories/{mem1.id}")
    assert del_resp.status_code in [200, 204]
    
    alice_resp_after_del = client.get("/api/v1/candidate/memories")
    remaining_ids = [m["id"] for m in alice_resp_after_del.json()]
    assert mem1.id not in remaining_ids
    assert mem2.id in remaining_ids

    # 6. Alice clears all memories (Right to be Forgotten)
    clear_resp = client.delete("/api/v1/candidate/memories")
    assert clear_resp.status_code == 200
    assert clear_resp.json()["deleted_count"] == 1
    assert clear_resp.json()["status"] in ["cleared", "purged"]

    final_resp = client.get("/api/v1/candidate/memories")
    assert len(final_resp.json()) == 0


# ===========================================================================
# 2. Memory Reuse Across Sessions Lifecycle
# ===========================================================================

def test_memory_reuse_across_sessions_lifecycle(client, test_db_session):
    """
    Lifecycle test proving:
    1. Conversation produces an eligible memory.
    2. The memory is persisted in SQLCandidateMemoryRepository.
    3. A later session for the same authorized candidate retrieves it and includes it in runtime prompt.
    4. A different candidate cannot receive it in their prompt.
    5. Deletion prevents the memory from being used in subsequent sessions.
    """
    cand_alice, job_alice = setup_candidate_and_job(test_db_session, "alice-uid")
    cand_bob, job_bob = setup_candidate_and_job(test_db_session, "bob-uid")

    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        uid="alice-uid", email="alice@test.com", display_name="Alice"
    )

    # Step 1 & 2: Conversation in Session 1 produces a durable memory
    # Create Session 1
    sess1_resp = client.post("/api/v1/sessions", json={
        "candidate_id": cand_alice.id,
        "job_id": job_alice.id,
        "interviewer_id": "marcus-arch-001",
        "difficulty": "realistic",
    })
    assert sess1_resp.status_code == 201
    session1_id = sess1_resp.json()["id"]

    # Conclude Session 1 with transcript sharing technical experience
    transcript = [
        {"role": "interviewer", "text": "What is your proudest engineering accomplishment?"},
        {"role": "candidate", "text": "I designed and deployed a distributed consensus engine using Raft in Go to coordinate our partition leases."},
    ]
    end_resp = client.post(f"/api/v1/sessions/{session1_id}/end", json={"transcript": transcript})
    assert end_resp.status_code == 200

    # Ensure memory was extracted and persisted
    mem_repo = SQLCandidateMemoryRepository(test_db_session)
    alice_memories = mem_repo.list("alice-uid")
    assert len(alice_memories) >= 1
    extracted_memory = alice_memories[0]
    assert "raft" in extracted_memory.content.lower() or "go" in extracted_memory.content.lower() or "consensus" in extracted_memory.content.lower()

    # Step 3 & 4: Start Session 2 for Alice and verify memory is included in runtime prompt
    runtime_svc = FitCheckRuntimeService()
    session_plan = InterviewSessionPlan(**sess1_resp.json()["session_plan"])

    alice_mems_dicts = [
        {"content": m.content, "category": m.category, "importance": m.importance}
        for m in alice_memories
    ]
    prompt_sess2 = runtime_svc.compile_runtime_prompt(
        candidate_data={
            "full_name": cand_alice.full_name,
            "headline": cand_alice.headline,
            "skills": cand_alice.skills,
            "projects": cand_alice.projects,
            "work_experience": cand_alice.work_experience,
        },
        job_data={
            "title": job_alice.title,
            "seniority": job_alice.seniority,
            "description": job_alice.description,
        },
        interviewer_data={
            "name": "Marcus Vance",
            "title": "Principal Architect",
            "company_context": "Systems Corp",
            "questioning_style": "direct",
        },
        session_plan=session_plan,
        memories=alice_mems_dicts,
    )

    assert "CANDIDATE PRACTICE MEMORY & HISTORICAL CONTEXT:" in prompt_sess2
    assert extracted_memory.content in prompt_sess2

    # Step 5: Check cross-candidate isolation: Bob's session does NOT contain Alice's memory
    bob_mems_dicts = [
        {"content": m.content, "category": m.category, "importance": m.importance}
        for m in mem_repo.list("bob-uid")
    ]
    prompt_bob = runtime_svc.compile_runtime_prompt(
        candidate_data={
            "full_name": cand_bob.full_name,
            "headline": cand_bob.headline,
            "skills": cand_bob.skills,
            "projects": cand_bob.projects,
            "work_experience": cand_bob.work_experience,
        },
        job_data={
            "title": job_bob.title,
            "seniority": job_bob.seniority,
            "description": job_bob.description,
        },
        interviewer_data={
            "name": "Marcus Vance",
            "title": "Principal Architect",
            "company_context": "Systems Corp",
            "questioning_style": "direct",
        },
        session_plan=session_plan,
        memories=bob_mems_dicts,
    )
    assert extracted_memory.content not in prompt_bob

    # Step 6: Deletion prevents the memory from being used in subsequent sessions
    del_res = client.delete(f"/api/v1/candidate/memories/{extracted_memory.id}")
    assert del_res.status_code in [200, 204]

    # Now verify Alice's memory list is empty and Session 3 prompt does not contain it
    alice_mems_remaining = [
        {"content": m.content, "category": m.category, "importance": m.importance}
        for m in mem_repo.list("alice-uid")
    ]
    assert len(alice_mems_remaining) == 0

    prompt_sess3 = runtime_svc.compile_runtime_prompt(
        candidate_data={
            "full_name": cand_alice.full_name,
            "headline": cand_alice.headline,
            "skills": cand_alice.skills,
            "projects": cand_alice.projects,
            "work_experience": cand_alice.work_experience,
        },
        job_data={
            "title": job_alice.title,
            "seniority": job_alice.seniority,
            "description": job_alice.description,
        },
        interviewer_data={
            "name": "Marcus Vance",
            "title": "Principal Architect",
            "company_context": "Systems Corp",
            "questioning_style": "direct",
        },
        session_plan=session_plan,
        memories=alice_mems_remaining,
    )
    assert "CANDIDATE PRACTICE MEMORY & HISTORICAL CONTEXT:" not in prompt_sess3
    assert extracted_memory.content not in prompt_sess3


# ===========================================================================
# 3. Interview Data Lifecycle Edge Cases & Error Handling
# ===========================================================================

def test_interview_data_lifecycle_edge_cases(client, test_db_session):
    """
    Verifies:
    1. Empty/missing transcript during session end handled cleanly (fallback signal, no 500 error).
    2. Duplicate completion requests are idempotent (return existing session and evaluation).
    3. Cross-candidate unauthorized conclusion attempts are rejected.
    """
    cand_alice, job_alice = setup_candidate_and_job(test_db_session, "alice-uid")

    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        uid="alice-uid", email="alice@test.com", display_name="Alice"
    )

    # 1. Create Session
    sess_resp = client.post("/api/v1/sessions", json={
        "candidate_id": cand_alice.id,
        "job_id": job_alice.id,
        "interviewer_id": "marcus-arch-001",
        "difficulty": "realistic",
    })
    assert sess_resp.status_code == 201
    session_id = sess_resp.json()["id"]

    # 2. Bob attempts to end Alice's session -> 404
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        uid="bob-uid", email="bob@test.com", display_name="Bob"
    )
    bob_end_resp = client.post(f"/api/v1/sessions/{session_id}/end", json={"transcript": []})
    assert bob_end_resp.status_code == 404

    # 3. Alice ends session with empty transcript (Simulates early disconnect / microphone issue)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser(
        uid="alice-uid", email="alice@test.com", display_name="Alice"
    )
    empty_end_resp = client.post(f"/api/v1/sessions/{session_id}/end", json={"transcript": []})
    assert empty_end_resp.status_code == 200
    ended_data = empty_end_resp.json()
    assert ended_data["status"] == "ended"

    # Evaluation was still generated with Insufficient Evidence/Signal
    eval_resp = client.get(f"/api/v1/evaluations/{session_id}")
    assert eval_resp.status_code == 200
    eval_data = eval_resp.json()
    assert eval_data["session_id"] == session_id
    assert eval_data["overall_recommendation"] in ["Insufficient Evidence", "Insufficient Signal", "No Hire"]

    # 4. Duplicate completion request (Idempotency test)
    # Calling /end again should not raise errors and should return the ended session
    dup_end_resp = client.post(f"/api/v1/sessions/{session_id}/end", json={"transcript": []})
    assert dup_end_resp.status_code == 200
    assert dup_end_resp.json()["status"] == "ended"

    # Evaluation is unchanged
    eval_resp_after_dup = client.get(f"/api/v1/evaluations/{session_id}")
    assert eval_resp_after_dup.json()["id"] == eval_data["id"]
