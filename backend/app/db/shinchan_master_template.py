"""Canonical master template and isolated workspace engine for Shinchan Nohara demo sessions.

Maintains one canonical, immutable Shinchan Nohara demo specification.
Every visitor receives their own cryptographically isolated workspace with cloned
mutable records in SQLite/PostgreSQL, preventing cross-tenant leakage or disruption.
"""

from __future__ import annotations

import copy
import logging
import secrets
from datetime import datetime, timedelta, timezone
from typing import Any
from sqlalchemy.orm import Session

from app.db.models import (
    CandidateModel,
    CandidatePracticeMemoryModel,
    InterviewEvaluationModel,
    InterviewSessionModel,
    JobModel,
    UserModel,
)

logger = logging.getLogger(__name__)

# Canonical Immutable Shinchan Nohara Template Definition
# This data is strictly read-only and is NEVER directly modified by any API caller.
SHINCHAN_CANONICAL_PROFILE: dict[str, Any] = {
    "full_name": "Shinchan Nohara",
    "headline": "Junior Software Development Engineer | Aspiring Systems Builder (Fictional Demo Candidate)",
    "resume_text": (
        "================================================================================\n"
        "[FICTIONAL DEMO CANDIDATE PROFILE — FITCHECK AI INTERVIEW PLATFORM]\n"
        "================================================================================\n"
        "Shinchan Nohara\n"
        "Email: shinchan.demo@fitcheck.io | Location: Mumbai / Kasukabe (Fictional)\n"
        "Portfolio: github.com/shinchan-actionkamen | Target: Junior SDE / Systems Engineer\n\n"
        "EDUCATION:\n"
        "Bachelor of Technology (B.Tech) in Computer Science & Engineering\n"
        "Indian Institute of Technology (IIT) Bombay — 2021 - 2025 (Fictional Demo Data)\n"
        "Relevant Coursework: Data Structures & Algorithms, Operating Systems, Database Management,\n"
        "Computer Networks, Object-Oriented Programming (C++), Distributed Systems Principles.\n\n"
        "TECHNICAL SKILLS:\n"
        "- Languages: Python, C++, SQL, JavaScript / TypeScript\n"
        "- Frameworks & Tools: FastAPI, Flask, React, Docker, Git, Redis, SQLite / PostgreSQL\n"
        "- Core Competencies: DSA, REST APIs, Real-Time Streaming, Concurrency, Computer Vision\n"
        "- Specializations: Multimodal AI Chatbots, Audio-Visual Integration, Creative Problem-Solving\n\n"
        "PROJECTS:\n"
        "1. Action Kamen AI Chatbot (Multimodal Conversational Persona Agent)\n"
        "   - Architected a real-time conversational AI agent adopting the 'Action Kamen' superhero persona.\n"
        "   - Integrated Gemini Live & WebRTC streaming to achieve sub-400ms end-to-end voice latency.\n"
        "   - Built custom prompt grounding and guardrails to keep responses heroically encouraging.\n\n"
        "2. Homework Manager (Automated Task Scheduler & Dependency Tracker)\n"
        "   - Developed a full-stack automated task planner with topological sorting for assignment dependencies.\n"
        "   - Implemented dynamic priority queuing based on urgency, difficulty, and available study hours.\n"
        "   - Built FastAPI REST backend with JWT authentication and responsive React frontend.\n\n"
        "3. Action Kamen Computer-Vision Gesture Detector\n"
        "   - Built real-time hand gesture recognition system using OpenCV and lightweight CNN models.\n"
        "   - Accurately detects the iconic 'Action Beam' pose with 94.2% precision at 45 FPS on edge devices.\n"
        "   - Triggers dynamic audio-visual animations upon verified superhero gesture recognition.\n\n"
        "WORK EXPERIENCE & INTERNSHIPS:\n"
        "Software Engineering Intern — Kasukabe Tech Labs (Fictional, Summer 2024)\n"
        "- Designed and deployed high-throughput telemetry logging microservice using Python & FastAPI.\n"
        "- Optimized JSON payload serialization, cutting internal API latency by 32% under load.\n"
        "- Authored automated unit test suites achieving 89% branch coverage.\n"
    ),
    "skills": [
        "Python",
        "C++",
        "Data Structures & Algorithms",
        "FastAPI",
        "Web Development",
        "AI Tools",
        "Computer Vision",
        "Creative Problem-Solving",
        "REST APIs",
        "SQL",
    ],
    "work_experience": [
        {
            "title": "Software Engineering Intern",
            "company": "Kasukabe Tech Labs (Fictional)",
            "start_date": "2024-05",
            "end_date": "2024-08",
            "highlights": [
                "Engineered high-throughput telemetry ingestion microservice with FastAPI and Redis queues.",
                "Optimized JSON payload serialization and memory reuse, cutting p95 response time by 32%.",
                "Wrote comprehensive Pytest integration test suites verifying edge-case error recovery.",
            ],
        }
    ],
    "projects": [
        {
            "title": "Action Kamen AI Chatbot",
            "technologies": ["Python", "FastAPI", "Gemini Live", "WebSockets"],
            "description": "Real-time multimodal superhero companion featuring dynamic voice synthesis and personality prompt guardrails.",
        },
        {
            "title": "Homework Manager",
            "technologies": ["Python", "FastAPI", "React", "PostgreSQL"],
            "description": "Automated dependency-based task scheduler using topological sorting and dynamic priority queuing.",
        },
        {
            "title": "Action Kamen Computer-Vision Gesture Detector",
            "technologies": ["Python", "OpenCV", "PyTorch", "NumPy"],
            "description": "Real-time gesture recognition detecting superhero pose at 45 FPS with 94.2% accuracy.",
        },
    ],
    "education": [
        {
            "degree": "B.Tech in Computer Science & Engineering",
            "institution": "Indian Institute of Technology (IIT) Bombay (Fictional Demo Data)",
            "start_year": "2021",
            "end_year": "2025",
            "highlights": "Focus on Algorithms, Systems Programming, and Applied AI.",
        }
    ],
}

SHINCHAN_CANONICAL_JOB: dict[str, Any] = {
    "title": "Software Development Engineer (SDE I)",
    "seniority": "Junior / Entry-Level (L3 / SDE I)",
    "description": (
        "Calibrated technical hiring standard for Junior Software Development Engineers (SDE I). "
        "Evaluates core data structures and algorithms, code quality in Python or C++, API design, "
        "and clear communication of technical trade-offs with creative problem-solving."
    ),
    "required_skills": [
        "Python",
        "C++",
        "Data Structures & Algorithms",
        "Web Development",
        "FastAPI",
        "Problem-Solving",
    ],
    "competencies": [
        {
            "name": "Data Structures & Algorithm Fluency",
            "criteria": [
                "Selects optimal data structures (hash maps, trees, heaps, priority queues) for task constraints.",
                "Analyzes and defends big-O time and space complexity with precision.",
            ],
        },
        {
            "name": "System & API Architecture Foundations",
            "criteria": [
                "Designs clean, RESTful APIs with sensible error handling and boundary validation.",
                "Understands fundamental concurrency, latency, and serialization trade-offs.",
            ],
        },
        {
            "name": "Code Clarity & Edge Case Handling",
            "criteria": [
                "Anticipates edge cases (null inputs, empty arrays, timeout errors, concurrency races).",
                "Writes readable, maintainable code with clear naming and modular separation.",
            ],
        },
        {
            "name": "Creative Problem-Solving & Socratic Defense",
            "criteria": [
                "Thinks out of the box when challenged with unconventional system constraints.",
                "Articulates reasoned defenses under Socratic pushback without defensive evasion.",
            ],
        },
    ],
}

SHINCHAN_CANONICAL_MEMORIES: list[dict[str, Any]] = [
    {
        "memory_type": "technical_strength",
        "competency_name": "Data Structures & Algorithm Fluency",
        "insight_summary": "Demonstrated swift intuition with topological sorting and graph cycle detection on task dependencies.",
    },
    {
        "memory_type": "growth_area",
        "competency_name": "System & API Architecture Foundations",
        "insight_summary": "Pushed to explain p99 tail latency vs p50 in streaming APIs; improve mathematical precision under Socratic probing.",
    },
    {
        "memory_type": "communication_pattern",
        "competency_name": "Creative Problem-Solving & Socratic Defense",
        "insight_summary": "Enthusiastic and creative analogies (referencing Action Kamen mechanics); balance informal analogies with formal engineering rigor.",
    },
]

SHINCHAN_SAMPLE_SESSIONS: list[dict[str, Any]] = [
    {
        "session_suffix": "sample-1",
        "interviewer_id": "alex-lead-001",
        "difficulty": "realistic",
        "opening_question": "Hi Shinchan! Welcome to FitCheck. Walk me through your Action Kamen AI chatbot project and how you handled response streaming latency.",
        "transcript": [
            {
                "role": "interviewer",
                "text": "Hi Shinchan! Welcome to FitCheck. Walk me through your Action Kamen AI chatbot project and how you handled response streaming latency.",
                "turn_index": 0,
                "turn_id": 1,
                "is_final": True,
            },
            {
                "role": "candidate",
                "text": "Thanks! For the Action Kamen chatbot, I used FastAPI with WebSockets to stream token chunks directly as they are generated by the LLM. To avoid buffering delays, I implemented chunked transfer encoding and kept prompt context cached in Redis.",
                "turn_index": 1,
                "turn_id": 2,
                "is_final": True,
            },
            {
                "role": "interviewer",
                "text": "Good approach with chunked streaming. How did you handle WebSocket disconnections when the candidate experiences network jitter?",
                "turn_index": 2,
                "turn_id": 3,
                "is_final": True,
            },
            {
                "role": "candidate",
                "text": "I added exponential backoff client reconnects with monotonic sequence numbers. When reconnecting, the client sends the last received chunk ID so the server resumes without dropping superhero dialogue mid-sentence.",
                "turn_index": 3,
                "turn_id": 4,
                "is_final": True,
            },
        ],
        "overall_score": 85.0,
        "recommendation": "Hire",
        "summary_verdict": "[Sample History] Shinchan demonstrated solid architectural intuition in WebSocket streaming, caching, and graceful reconnect recovery for the Action Kamen project. Communicated trade-offs with high enthusiasm.",
        "competency_scores": [
            {
                "competency_name": "Data Structures & Algorithm Fluency",
                "score": 86.0,
                "status": "met",
                "evidence_quotes": [
                    "I implemented chunked transfer encoding and kept prompt context cached in Redis.",
                ],
                "reasoning": "Correctly leveraged sequence-based monotonic caching for streaming tokens.",
            },
            {
                "competency_name": "System & API Architecture Foundations",
                "score": 84.0,
                "status": "met",
                "evidence_quotes": [
                    "I added exponential backoff client reconnects with monotonic sequence numbers.",
                ],
                "reasoning": "Demonstrated sound understanding of transient network failure mitigation.",
            },
            {
                "competency_name": "Code Clarity & Edge Case Handling",
                "score": 83.0,
                "status": "met",
                "evidence_quotes": [
                    "the client sends the last received chunk ID so the server resumes without dropping superhero dialogue",
                ],
                "reasoning": "Accounted for dropped packets and resumption boundaries effectively.",
            },
            {
                "competency_name": "Creative Problem-Solving & Socratic Defense",
                "score": 87.0,
                "status": "exceeded",
                "evidence_quotes": [
                    "resumes without dropping superhero dialogue mid-sentence.",
                ],
                "reasoning": "Creative, engaging communication anchored by solid practical implementation.",
            },
        ],
        "strengths": [
            "Strong grasp of full-duplex WebSocket streaming and token buffering.",
            "Proactive consideration of reconnection protocol edge cases.",
        ],
        "gaps": [
            "Can deepen quantitative analysis of Redis memory consumption under high concurrent connections.",
        ],
        "recommendations": [
            "Practice distributed load-balancing exercises and backpressure handling for streaming APIs.",
        ],
    },
    {
        "session_suffix": "sample-2",
        "interviewer_id": "sarah-em-001",
        "difficulty": "challenging",
        "opening_question": "Hello Shinchan. Tell me about a time on the Homework Manager project where you faced conflicting priorities and had to make an architectural compromise.",
        "transcript": [
            {
                "role": "interviewer",
                "text": "Hello Shinchan. Tell me about a time on the Homework Manager project where you faced conflicting priorities and had to make an architectural compromise.",
                "turn_index": 0,
                "turn_id": 1,
                "is_final": True,
            },
            {
                "role": "candidate",
                "text": "During exam week, users needed both instant sub-second schedule recalculations and multi-device calendar sync. Computing all permutations on the backend was too slow, so I compromised by using client-side topological sorting for instant UI feedback while lazily syncing the database in the background.",
                "turn_index": 1,
                "turn_id": 2,
                "is_final": True,
            },
            {
                "role": "interviewer",
                "text": "What happened if the background sync failed while the user closed their browser?",
                "turn_index": 2,
                "turn_id": 3,
                "is_final": True,
            },
            {
                "role": "candidate",
                "text": "I used IndexedDB as a write-ahead log on the browser. On the next visit, an uncommitted transaction banner prompted an automatic reconciliation with server timestamps to prevent data loss.",
                "turn_index": 3,
                "turn_id": 4,
                "is_final": True,
            },
        ],
        "overall_score": 88.0,
        "recommendation": "Strong Hire",
        "summary_verdict": "[Sample History] Exceptional ownership and pragmatic architecture on the Homework Manager project. Demonstrated strong STAR depth and clear understanding of offline-first consistency trade-offs.",
        "competency_scores": [
            {
                "competency_name": "Data Structures & Algorithm Fluency",
                "score": 88.0,
                "status": "exceeded",
                "evidence_quotes": [
                    "using client-side topological sorting for instant UI feedback",
                ],
                "reasoning": "Appropriate algorithm selection for local dependency graph resolution.",
            },
            {
                "competency_name": "System & API Architecture Foundations",
                "score": 89.0,
                "status": "exceeded",
                "evidence_quotes": [
                    "I used IndexedDB as a write-ahead log on the browser.",
                ],
                "reasoning": "Offline-first architectural pattern with clear reconciliation strategy.",
            },
            {
                "competency_name": "Code Clarity & Edge Case Handling",
                "score": 86.0,
                "status": "met",
                "evidence_quotes": [
                    "reconciliation with server timestamps to prevent data loss.",
                ],
                "reasoning": "Conflict resolution based on monotonic timestamp ordering.",
            },
            {
                "competency_name": "Creative Problem-Solving & Socratic Defense",
                "score": 89.0,
                "status": "exceeded",
                "evidence_quotes": [
                    "uncommitted transaction banner prompted an automatic reconciliation",
                ],
                "reasoning": "High candidate agency and pragmatic product engineering mindset.",
            },
        ],
        "strengths": [
            "Clear articulation of offline-first design trade-offs.",
            "Strong user empathy paired with technical rigor.",
        ],
        "gaps": [
            "Could explore CRDTs (Conflict-free Replicated Data Types) for multi-device concurrent offline edits.",
        ],
        "recommendations": [
            "Study distributed consensus and CRDT data structures for multi-master collaborative state.",
        ],
    },
]


def provision_isolated_demo_workspace(db: Session) -> tuple[str, str, str]:
    """Atomically provisions a fresh, isolated workspace cloned from the Shinchan master template.

    Generates a cryptographically random workspace ID, copies all canonical profile,
    job, memory, and sample evaluation records into tenant-isolated database rows,
    and returns (demo_token, workspace_id, candidate_id).
    """
    from app.core.demo_token import create_demo_token
    from app.db.seed_presets import seed_interviewer_presets

    seed_interviewer_presets(db)

    # 1. Generate unique random IDs
    rand_suffix = secrets.token_hex(6)
    workspace_id = f"demo-ws-{rand_suffix}"
    candidate_id = f"cand-shinchan-{rand_suffix}"
    job_id = f"job-shinchan-sde-{rand_suffix}"

    # 2. Create isolated User account in database
    user_record = UserModel(
        id=workspace_id,
        email=f"shinchan.{rand_suffix}@demo.fitcheck.io",
        display_name="Shinchan Nohara (Demo Workspace)",
    )
    db.add(user_record)
    db.flush()

    # 3. Clone Candidate Profile from Master Template
    candidate_record = CandidateModel(
        id=candidate_id,
        user_id=workspace_id,
        full_name=SHINCHAN_CANONICAL_PROFILE["full_name"],
        headline=SHINCHAN_CANONICAL_PROFILE["headline"],
        resume_text=SHINCHAN_CANONICAL_PROFILE["resume_text"],
        skills=copy.deepcopy(SHINCHAN_CANONICAL_PROFILE["skills"]),
        work_experience=copy.deepcopy(SHINCHAN_CANONICAL_PROFILE["work_experience"]),
        projects=copy.deepcopy(SHINCHAN_CANONICAL_PROFILE["projects"]),
        education=copy.deepcopy(SHINCHAN_CANONICAL_PROFILE["education"]),
    )
    db.add(candidate_record)

    # 4. Clone Target SDE Job from Master Template
    job_record = JobModel(
        id=job_id,
        user_id=workspace_id,
        title=SHINCHAN_CANONICAL_JOB["title"],
        seniority=SHINCHAN_CANONICAL_JOB["seniority"],
        description=SHINCHAN_CANONICAL_JOB["description"],
        required_skills=copy.deepcopy(SHINCHAN_CANONICAL_JOB["required_skills"]),
        competencies=copy.deepcopy(SHINCHAN_CANONICAL_JOB["competencies"]),
    )
    db.add(job_record)
    db.flush()

    # 5. Clone Practice Memories into this Workspace
    now_iso = datetime.now(timezone.utc).isoformat()
    for i, mem in enumerate(SHINCHAN_CANONICAL_MEMORIES):
        mem_id = f"mem-{rand_suffix}-{i+1}"
        db.add(
            CandidatePracticeMemoryModel(
                id=mem_id,
                character_id="alex-arch-001",
                user_id=workspace_id,
                content=f"[{mem['competency_name']}] {mem['insight_summary']}",
                category=mem["memory_type"],
                importance=0.9,
                created_at=now_iso,
            )
        )

    # 6. Clone Sample History (Clearly marked as Sample History)
    now = datetime.now(timezone.utc)
    for sample in SHINCHAN_SAMPLE_SESSIONS:
        sample_sess_id = f"sess-{rand_suffix}-{sample['session_suffix']}"
        sample_eval_id = f"eval-{rand_suffix}-{sample['session_suffix']}"
        session_plan = {
            "opening_question": sample["opening_question"],
            "difficulty_config": {"tone": sample["difficulty"]},
            "is_sample_history": True,
        }

        sess_row = InterviewSessionModel(
            id=sample_sess_id,
            user_id=workspace_id,
            candidate_id=candidate_id,
            job_id=job_id,
            interviewer_id=sample["interviewer_id"],
            difficulty=sample["difficulty"],
            status="completed",
            channel=f"sample-channel-{sample_sess_id}",
            session_plan=session_plan,
            transcript=copy.deepcopy(sample["transcript"]),
            started_at=now - timedelta(days=2),
            ended_at=now - timedelta(days=2, minutes=-25),
        )
        db.add(sess_row)
        db.flush()

        eval_row = InterviewEvaluationModel(
            id=sample_eval_id,
            session_id=sample_sess_id,
            user_id=workspace_id,
            overall_score=sample["overall_score"],
            overall_recommendation=sample["recommendation"],
            summary_verdict=sample["summary_verdict"],
            competency_scores=copy.deepcopy(sample["competency_scores"]),
            observed_strengths=copy.deepcopy(sample["strengths"]),
            technical_gaps=copy.deepcopy(sample["gaps"]),
            preparation_recommendations=copy.deepcopy(sample["recommendations"]),
        )
        db.add(eval_row)

    db.commit()

    # 7. Create signed HMAC-SHA256 demo token
    token = create_demo_token(
        uid=workspace_id,
        email=user_record.email,
        display_name=SHINCHAN_CANONICAL_PROFILE["full_name"],
        candidate_id=candidate_id,
        workspace_id=workspace_id,
    )

    logger.info(
        "[DEMO_ENGINE] Provisioned isolated Shinchan demo workspace '%s' (candidate '%s')",
        workspace_id,
        candidate_id,
    )

    return token, workspace_id, candidate_id


def reset_isolated_demo_workspace(db: Session, workspace_id: str) -> dict[str, Any]:
    """Resets only the specified visitor's workspace back to the clean Shinchan template.

    Preserves any active/in_progress interviews in that workspace, and NEVER touches
    other concurrent visitors' workspaces or the canonical master template.
    """
    user = db.query(UserModel).filter(UserModel.id == workspace_id).first()
    if not user:
        raise ValueError(f"Workspace '{workspace_id}' not found.")

    logger.info("[DEMO_ENGINE] Resetting isolated demo workspace '%s'", workspace_id)

    # 1. Identify active sessions to protect in this workspace
    active_session_ids = [
        s.id
        for s in db.query(InterviewSessionModel)
        .filter(
            InterviewSessionModel.user_id == workspace_id,
            InterviewSessionModel.status.in_(["in_progress", "active"]),
        )
        .all()
    ]

    # 2. Delete non-active evaluations and sessions for this workspace only
    if active_session_ids:
        db.query(InterviewEvaluationModel).filter(
            InterviewEvaluationModel.user_id == workspace_id,
            ~InterviewEvaluationModel.session_id.in_(active_session_ids),
        ).delete(synchronize_session=False)
        db.query(InterviewSessionModel).filter(
            InterviewSessionModel.user_id == workspace_id,
            ~InterviewSessionModel.id.in_(active_session_ids),
        ).delete(synchronize_session=False)
    else:
        db.query(InterviewEvaluationModel).filter(
            InterviewEvaluationModel.user_id == workspace_id
        ).delete(synchronize_session=False)
        db.query(InterviewSessionModel).filter(
            InterviewSessionModel.user_id == workspace_id
        ).delete(synchronize_session=False)

    db.query(CandidatePracticeMemoryModel).filter(
        CandidatePracticeMemoryModel.user_id == workspace_id
    ).delete(synchronize_session=False)

    # Re-sync candidate profile to pristine Shinchan template
    cand = db.query(CandidateModel).filter(CandidateModel.user_id == workspace_id).first()
    if cand:
        cand.full_name = SHINCHAN_CANONICAL_PROFILE["full_name"]
        cand.headline = SHINCHAN_CANONICAL_PROFILE["headline"]
        cand.resume_text = SHINCHAN_CANONICAL_PROFILE["resume_text"]
        cand.skills = copy.deepcopy(SHINCHAN_CANONICAL_PROFILE["skills"])
        cand.work_experience = copy.deepcopy(SHINCHAN_CANONICAL_PROFILE["work_experience"])
        cand.projects = copy.deepcopy(SHINCHAN_CANONICAL_PROFILE["projects"])
        cand.education = copy.deepcopy(SHINCHAN_CANONICAL_PROFILE["education"])
        cand.raw_resume_filename = None
        cand.updated_at = datetime.now(timezone.utc)
    else:
        cand = CandidateModel(
            id=f"cand-{workspace_id}",
            user_id=workspace_id,
            full_name=SHINCHAN_CANONICAL_PROFILE["full_name"],
            headline=SHINCHAN_CANONICAL_PROFILE["headline"],
            resume_text=SHINCHAN_CANONICAL_PROFILE["resume_text"],
            skills=copy.deepcopy(SHINCHAN_CANONICAL_PROFILE["skills"]),
            work_experience=copy.deepcopy(SHINCHAN_CANONICAL_PROFILE["work_experience"]),
            projects=copy.deepcopy(SHINCHAN_CANONICAL_PROFILE["projects"]),
            education=copy.deepcopy(SHINCHAN_CANONICAL_PROFILE["education"]),
        )
        db.add(cand)

    db.flush()

    # Re-seed sample practice memories
    now_iso = datetime.now(timezone.utc).isoformat()
    for i, mem in enumerate(SHINCHAN_CANONICAL_MEMORIES):
        mem_id = f"mem-{workspace_id}-{i+1}"
        db.add(
            CandidatePracticeMemoryModel(
                id=mem_id,
                character_id="alex-arch-001",
                user_id=workspace_id,
                content=f"[{mem['competency_name']}] {mem['insight_summary']}",
                category=mem["memory_type"],
                importance=0.9,
                created_at=now_iso,
            )
        )

    # Re-seed pristine sample evaluations
    now = datetime.now(timezone.utc)
    job = db.query(JobModel).filter(JobModel.user_id == workspace_id).first()
    job_id = job.id if job else f"job-{workspace_id}"

    for sample in SHINCHAN_SAMPLE_SESSIONS:
        sample_sess_id = f"sess-{workspace_id}-{sample['session_suffix']}"
        sample_eval_id = f"eval-{workspace_id}-{sample['session_suffix']}"
        session_plan = {
            "opening_question": sample["opening_question"],
            "difficulty_config": {"tone": sample["difficulty"]},
            "is_sample_history": True,
        }

        sess_row = InterviewSessionModel(
            id=sample_sess_id,
            user_id=workspace_id,
            candidate_id=cand.id,
            job_id=job_id,
            interviewer_id=sample["interviewer_id"],
            difficulty=sample["difficulty"],
            status="completed",
            channel=f"sample-channel-{sample_sess_id}",
            session_plan=session_plan,
            transcript=copy.deepcopy(sample["transcript"]),
            started_at=now - timedelta(days=2),
            ended_at=now - timedelta(days=2, minutes=-25),
        )
        db.add(sess_row)
        db.flush()

        eval_row = InterviewEvaluationModel(
            id=sample_eval_id,
            session_id=sample_sess_id,
            user_id=workspace_id,
            overall_score=sample["overall_score"],
            overall_recommendation=sample["recommendation"],
            summary_verdict=sample["summary_verdict"],
            competency_scores=copy.deepcopy(sample["competency_scores"]),
            observed_strengths=copy.deepcopy(sample["strengths"]),
            technical_gaps=copy.deepcopy(sample["gaps"]),
            preparation_recommendations=copy.deepcopy(sample["recommendations"]),
        )
        db.add(eval_row)

    db.commit()

    return {
        "workspace_id": workspace_id,
        "candidate_id": cand.id,
        "active_sessions_preserved": len(active_session_ids),
        "status": "reset_to_pristine_shinchan",
    }


def cleanup_expired_demo_workspaces(db: Session, max_age_hours: int = 48) -> int:
    """Safely cleans up stale demo workspaces older than max_age_hours.

    Explicitly preserves any demo workspace that currently has an active or
    in-progress interview session in flight.
    """
    cutoff = datetime.now(timezone.utc) - timedelta(hours=max_age_hours)
    stale_users = (
        db.query(UserModel)
        .filter(
            UserModel.id.like("demo-ws-%"),
            UserModel.created_at < cutoff,
        )
        .all()
    )

    cleaned_count = 0
    for u in stale_users:
        has_active_sessions = (
            db.query(InterviewSessionModel)
            .filter(
                InterviewSessionModel.user_id == u.id,
                InterviewSessionModel.status.in_(["in_progress", "active"]),
            )
            .first()
            is not None
        )
        if not has_active_sessions:
            db.delete(u)
            cleaned_count += 1

    if cleaned_count > 0:
        db.commit()
        logger.info("[DEMO_ENGINE] Cleaned up %d expired demo workspaces", cleaned_count)

    return cleaned_count
