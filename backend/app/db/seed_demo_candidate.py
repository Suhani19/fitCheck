"""Idempotent seed data for the dedicated FitCheck demo candidate.

Provides realistic sample profile, job, completed interview sessions, evaluations,
evidence quotes, and practice memories so that the dashboard, scorecard, comparison,
and analytics have meaningful, high-fidelity content out of the box.
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
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

DEMO_USER_ID = "demo-candidate-elena"
DEMO_CANDIDATE_ID = "demo-elena-cand"
DEMO_JOB_ID = "demo-job-dist-sys"
DEMO_SESSION_1_ID = "demo-session-8094"
DEMO_SESSION_2_ID = "demo-session-7912"
DEMO_EVAL_1_ID = "demo-eval-8094"
DEMO_EVAL_2_ID = "demo-eval-7912"


def seed_demo_candidate(db: Session, force_reset: bool = False) -> dict:
    """Idempotently seed or reset the demo candidate and historical data."""
    if force_reset:
        logger.info("Resetting demo candidate data...")
        # Preserve any active/in_progress sessions so user interviews in flight are never wiped
        active_session_ids = [
            s.id for s in db.query(InterviewSessionModel).filter(
                InterviewSessionModel.user_id == DEMO_USER_ID,
                InterviewSessionModel.status.in_(["in_progress", "active"])
            ).all()
        ]
        if active_session_ids:
            db.query(InterviewEvaluationModel).filter(
                InterviewEvaluationModel.user_id == DEMO_USER_ID,
                ~InterviewEvaluationModel.session_id.in_(active_session_ids)
            ).delete(synchronize_session=False)
            db.query(InterviewSessionModel).filter(
                InterviewSessionModel.user_id == DEMO_USER_ID,
                ~InterviewSessionModel.id.in_(active_session_ids)
            ).delete(synchronize_session=False)
        else:
            db.query(InterviewEvaluationModel).filter(InterviewEvaluationModel.user_id == DEMO_USER_ID).delete(synchronize_session=False)
            db.query(InterviewSessionModel).filter(InterviewSessionModel.user_id == DEMO_USER_ID).delete(synchronize_session=False)
        db.query(CandidatePracticeMemoryModel).filter(CandidatePracticeMemoryModel.user_id == DEMO_USER_ID).delete()
        db.query(JobModel).filter(JobModel.user_id == DEMO_USER_ID).delete()
        db.query(CandidateModel).filter(CandidateModel.user_id == DEMO_USER_ID).delete()
        db.query(UserModel).filter(UserModel.id == DEMO_USER_ID).delete()
        db.commit()

    # 1. User Account
    user = db.query(UserModel).filter(UserModel.id == DEMO_USER_ID).first()
    if not user:
        user = UserModel(
            id=DEMO_USER_ID,
            email="elena.demo@fitcheck.io",
            display_name="Elena Rostova",
        )
        db.add(user)
        db.commit()

    # 2. Candidate Profile
    candidate = db.query(CandidateModel).filter(CandidateModel.id == DEMO_CANDIDATE_ID).first()
    if not candidate:
        candidate = CandidateModel(
            id=DEMO_CANDIDATE_ID,
            user_id=DEMO_USER_ID,
            full_name="Elena Rostova",
            headline="Senior Distributed Systems Engineer @ Stripe",
            resume_text=(
                "Elena Rostova — Senior Distributed Systems Engineer\n"
                "Experience: Stripe (2022-Present): Led transactional consensus layer handling 80M ops/sec. "
                "Implemented Raft leader leasing protocol reducing read latency by 68%.\n"
                "Datadog (2019-2022): Built real-time telemetry streaming pipelines using Kafka and Go.\n"
                "Education: M.S. Computer Science, University of Washington."
            ),
            skills=[
                "Go",
                "Distributed Systems",
                "Raft",
                "Kubernetes",
                "High Concurrency",
                "gRPC",
                "Fault Tolerance",
                "PostgreSQL",
                "Database Sharding",
            ],
            work_experience=[
                {
                    "title": "Senior Distributed Systems Engineer",
                    "company": "Stripe",
                    "start_date": "2022-03",
                    "end_date": "Present",
                    "highlights": [
                        "Architected distributed transactional primitives handling 80M+ daily transactions.",
                        "Implemented Raft leader lease mechanism, cutting monotonic read tail latency by 68%.",
                        "Designed split-brain detection and automatic fencing token mitigation for distributed lock services.",
                    ],
                },
                {
                    "title": "Infrastructure Software Engineer",
                    "company": "Datadog",
                    "start_date": "2019-06",
                    "end_date": "2022-02",
                    "highlights": [
                        "Scaled real-time metrics ingestion engine in Go, ingesting 15TB of streaming timeseries data daily.",
                        "Reduced garbage collection pauses by 42% through off-heap buffer pooling and memory reuse.",
                    ],
                },
            ],
            projects=[
                {
                    "name": "miniraft",
                    "description": "Educational, zero-dependency Go implementation of Raft consensus with leader election, log compaction, and membership changes.",
                    "url": "https://github.com/elena-rostova/miniraft",
                    "stars": 420,
                },
                {
                    "name": "goshard",
                    "description": "Consistent hashing proxy for horizontal PostgreSQL sharding with zero-downtime rebalancing.",
                    "url": "https://github.com/elena-rostova/goshard",
                    "stars": 280,
                },
            ],
            education=[
                {
                    "institution": "University of Washington",
                    "degree": "M.S. in Computer Science",
                    "graduation_year": 2019,
                },
                {
                    "institution": "UC Berkeley",
                    "degree": "B.S. in Electrical Engineering & Computer Science",
                    "graduation_year": 2017,
                },
            ],
        )
        db.add(candidate)
        db.commit()

    # 3. Target Job & Calibrated Rubric
    job = db.query(JobModel).filter(JobModel.id == DEMO_JOB_ID).first()
    if not job:
        job = JobModel(
            id=DEMO_JOB_ID,
            user_id=DEMO_USER_ID,
            title="Staff Distributed Systems Engineer",
            seniority="Staff / L6",
            description=(
                "Architect resilient, fault-tolerant distributed transactional primitives, state-machine replication, "
                "and consensus pipelines powering global payments infrastructure at scale."
            ),
            required_skills=[
                "Raft",
                "Distributed Storage",
                "Consensus",
                "Go",
                "High Concurrency",
                "PostgreSQL",
            ],
            competencies=[
                {
                    "name": "System Design & Architecture",
                    "weight": 0.35,
                    "description": "State machine replication, RPC pipeline decomposition, partition tolerance.",
                },
                {
                    "name": "Concurrency & Scalability",
                    "weight": 0.25,
                    "description": "Optimistic concurrency control, deadlock detection, lock-free queues.",
                },
                {
                    "name": "Failure Modes & Fault Tolerance",
                    "weight": 0.25,
                    "description": "Split-brain mitigations, network partition healing, monotonic fencing tokens.",
                },
                {
                    "name": "Technical Communication",
                    "weight": 0.15,
                    "description": "Crisp requirement framing, constructive Socratic trade-off articulation.",
                },
            ],
        )
        db.add(job)
        db.commit()

    now = datetime.now(timezone.utc)

    # 4. Completed Interview Session 1 (High Score - Strong Hire)
    sess1 = db.query(InterviewSessionModel).filter(InterviewSessionModel.id == DEMO_SESSION_1_ID).first()
    if not sess1:
        started_1 = now - timedelta(days=2, hours=3)
        ended_1 = started_1 + timedelta(minutes=34)
        sess1 = InterviewSessionModel(
            id=DEMO_SESSION_1_ID,
            user_id=DEMO_USER_ID,
            candidate_id=DEMO_CANDIDATE_ID,
            job_id=DEMO_JOB_ID,
            interviewer_id="marcus-arch-001",
            difficulty="challenging",
            status="completed",
            channel="fitcheck-demo-sess-8094",
            agent_id="agora-cloud-agent-demo-01",
            started_at=started_1,
            ended_at=ended_1,
            session_plan={
                "scenario": "Raft Consensus Protocols & Network Partition Mitigation",
                "opening_question": (
                    "Elena, let's explore distributed consensus. In a 5-node Raft cluster, suppose a network partition "
                    "isolates 2 nodes including the current leader. How do you prevent stale or uncommitted reads on the isolated leader?"
                ),
            },
            transcript=[
                {
                    "role": "interviewer",
                    "text": "Elena, let's explore distributed consensus. In a 5-node Raft cluster, suppose a network partition isolates 2 nodes including the current leader. How do you prevent stale or uncommitted reads on the isolated leader?",
                    "timestamp": started_1.isoformat(),
                },
                {
                    "role": "candidate",
                    "text": "To guarantee linearizable reads without forcing every read through the full Raft log, we can employ leader leases or a round of heartbeat acknowledgments with the majority quorum before responding.",
                    "timestamp": (started_1 + timedelta(seconds=25)).isoformat(),
                },
                {
                    "role": "interviewer",
                    "text": "What happens if local clock drift causes the old leader to believe its lease is still valid after the majority partition has already elected a new leader?",
                    "timestamp": (started_1 + timedelta(seconds=55)).isoformat(),
                },
                {
                    "role": "candidate",
                    "text": "That is a known hazard with pure physical clock leases. To eliminate clock skew vulnerability, we use bounded monotonic clock durations where the lease duration is strictly shorter than the minimum election timeout, or we fall back to quorum read-index confirmation.",
                    "timestamp": (started_1 + timedelta(seconds=90)).isoformat(),
                },
                {
                    "role": "interviewer",
                    "text": "Walk me through how read-index handles this under high concurrency.",
                    "timestamp": (started_1 + timedelta(seconds=130)).isoformat(),
                },
                {
                    "role": "candidate",
                    "text": "The leader queries its current commit index, sends an async heartbeat round to confirm it is still the legitimate leader to a quorum, and once confirmed, reads from the local state machine once applied index matches read-index.",
                    "timestamp": (started_1 + timedelta(seconds=175)).isoformat(),
                },
            ],
        )
        db.add(sess1)
        db.commit()

        eval1 = InterviewEvaluationModel(
            id=DEMO_EVAL_1_ID,
            session_id=DEMO_SESSION_1_ID,
            user_id=DEMO_USER_ID,
            overall_score=88.0,
            overall_recommendation="Strong Hire",
            summary_verdict=(
                "Elena demonstrated exceptional rigor in distributed consensus mechanics, articulating precise "
                "mathematical trade-offs between physical clock drift hazards in leader leases versus latency overhead "
                "in quorum read-index verification."
            ),
            competency_scores=[
                {
                    "name": "System Design & Architecture",
                    "score": 92.0,
                    "feedback": "Outstanding comprehension of consensus state machine replication.",
                    "evidence_quotes": [
                        "To guarantee linearizable reads without forcing every read through the full Raft log, we can employ leader leases..."
                    ],
                },
                {
                    "name": "Concurrency & Scalability",
                    "score": 86.0,
                    "feedback": "Clear explanation of async heartbeat pipelining and commit-index tracking.",
                    "evidence_quotes": [
                        "The leader queries its current commit index, sends an async heartbeat round to confirm it is still the legitimate leader..."
                    ],
                },
                {
                    "name": "Failure Modes & Fault Tolerance",
                    "score": 90.0,
                    "feedback": "Mastery of asymmetric network partitions and split-brain lease expiry.",
                    "evidence_quotes": [
                        "To eliminate clock skew vulnerability, we use bounded monotonic clock durations where lease is shorter than election timeout..."
                    ],
                },
                {
                    "name": "Technical Communication",
                    "score": 84.0,
                    "feedback": "Concise, structured Socratic responses with zero architectural hand-waving.",
                    "evidence_quotes": [
                        "That is a known hazard with pure physical clock leases."
                    ],
                },
            ],
            observed_strengths=[
                "Deep architectural command of Raft consensus invariants and monotonic clock assumptions.",
                "Instinctively addressed split-brain edge cases and asymmetric network partitions without prompting.",
                "Crisp, authoritative communication style calibrated for Principal and Staff level interview loops.",
            ],
            technical_gaps=[
                "Could have touched on write amplification and compaction stalling in the underlying LSM-tree storage engine.",
            ],
            preparation_recommendations=[
                "Review LSM compaction strategies (Leveled vs Tiered) under write-heavy transactional burst workloads.",
                "Practice sparring on zero-trust mutual TLS certificate rotation in multi-region service meshes.",
            ],
        )
        db.add(eval1)
        db.commit()

    # 5. Completed Interview Session 2 (Baseline Score - Lean Hire)
    sess2 = db.query(InterviewSessionModel).filter(InterviewSessionModel.id == DEMO_SESSION_2_ID).first()
    if not sess2:
        started_2 = now - timedelta(days=6, hours=5)
        ended_2 = started_2 + timedelta(minutes=28)
        sess2 = InterviewSessionModel(
            id=DEMO_SESSION_2_ID,
            user_id=DEMO_USER_ID,
            candidate_id=DEMO_CANDIDATE_ID,
            job_id=DEMO_JOB_ID,
            interviewer_id="alex-lead-001",
            difficulty="realistic",
            status="completed",
            channel="fitcheck-demo-sess-7912",
            agent_id="agora-cloud-agent-demo-02",
            started_at=started_2,
            ended_at=ended_2,
            session_plan={
                "scenario": "Distributed Locking & Redis vs etcd Coordination",
                "opening_question": (
                    "Elena, suppose we need to build a distributed lock service for idempotent charge settlement. "
                    "Would you choose Redis with Redlock or etcd with lease grants, and why?"
                ),
            },
            transcript=[
                {
                    "role": "interviewer",
                    "text": "Elena, suppose we need to build a distributed lock service for idempotent charge settlement. Would you choose Redis with Redlock or etcd with lease grants, and why?",
                    "timestamp": started_2.isoformat(),
                },
                {
                    "role": "candidate",
                    "text": "For critical financial charge settlements where double-spend cannot occur, I would choose etcd or Raft-backed consensus over Redis Redlock, because etcd provides strong linearizability guarantees.",
                    "timestamp": (started_2 + timedelta(seconds=20)).isoformat(),
                },
                {
                    "role": "interviewer",
                    "text": "What failure mode in Redlock specifically makes it problematic for financial idempotency?",
                    "timestamp": (started_2 + timedelta(seconds=45)).isoformat(),
                },
                {
                    "role": "candidate",
                    "text": "Redlock relies on synchronous clock synchronization across separate Redis nodes. A sudden NTP jump or process pause can cause node locks to expire while the client still believes it owns the lock.",
                    "timestamp": (started_2 + timedelta(seconds=75)).isoformat(),
                },
            ],
        )
        db.add(sess2)
        db.commit()

        eval2 = InterviewEvaluationModel(
            id=DEMO_EVAL_2_ID,
            session_id=DEMO_SESSION_2_ID,
            user_id=DEMO_USER_ID,
            overall_score=72.0,
            overall_recommendation="Lean Hire",
            summary_verdict=(
                "Solid pragmatic system architecture sensibilities and sound understanding of Redlock clock drift "
                "hazards, but initial proposal omitted fencing tokens required to protect downstream storage systems."
            ),
            competency_scores=[
                {
                    "name": "System Design & Architecture",
                    "score": 75.0,
                    "feedback": "Good choice of etcd over Redis for critical transactional coordination.",
                    "evidence_quotes": [
                        "For critical financial charge settlements where double-spend cannot occur, I would choose etcd..."
                    ],
                },
                {
                    "name": "Concurrency & Scalability",
                    "score": 70.0,
                    "feedback": "Correctly identified GC pause and NTP stepping vulnerabilities.",
                    "evidence_quotes": [
                        "Redlock relies on synchronous clock synchronization across separate Redis nodes."
                    ],
                },
                {
                    "name": "Failure Modes & Fault Tolerance",
                    "score": 68.0,
                    "feedback": "Initial design failed to include monotonic fencing tokens on downstream database writes.",
                    "evidence_quotes": [
                        "A sudden NTP jump or process pause can cause node locks to expire..."
                    ],
                },
                {
                    "name": "Technical Communication",
                    "score": 75.0,
                    "feedback": "Direct and articulate answers, with good pacing.",
                    "evidence_quotes": [
                        "For critical financial charge settlements where double-spend cannot occur..."
                    ],
                },
            ],
            observed_strengths=[
                "Strong grasp of CAP theorem trade-offs between Redis performance and etcd CP consistency.",
                "Accurately articulated Martin Kleppmann's critique of Redlock clock synchronization.",
            ],
            technical_gaps=[
                "Neglected monotonic fencing tokens (e.g. zxid/raft index) on lock acquisition to reject late zombie requests.",
            ],
            preparation_recommendations=[
                "Study fencing tokens and epoch counters in distributed storage protocols.",
            ],
        )
        db.add(eval2)
        db.commit()

    # 6. Candidate Practice Memory Items
    mem1 = db.query(CandidatePracticeMemoryModel).filter(CandidatePracticeMemoryModel.id == "mem-demo-1").first()
    if not mem1:
        mem1 = CandidatePracticeMemoryModel(
            id="mem-demo-1",
            character_id="marcus-arch-001",
            user_id=DEMO_USER_ID,
            session_id=DEMO_SESSION_2_ID,
            content="Candidate initially overlooked monotonic fencing tokens to prevent late writes from paused processes in distributed lock designs.",
            category="technical_gaps",
            importance=0.85,
            created_at=(now - timedelta(days=6)).isoformat(),
        )
        db.add(mem1)

    mem2 = db.query(CandidatePracticeMemoryModel).filter(CandidatePracticeMemoryModel.id == "mem-demo-2").first()
    if not mem2:
        mem2 = CandidatePracticeMemoryModel(
            id="mem-demo-2",
            character_id="marcus-arch-001",
            user_id=DEMO_USER_ID,
            session_id=DEMO_SESSION_1_ID,
            content="Articulated Raft leader lease safety invariants and clock drift bounding with exceptional precision under Socratic interrogation.",
            category="observed_strengths",
            importance=0.92,
            created_at=(now - timedelta(days=2)).isoformat(),
        )
        db.add(mem2)

    db.commit()
    logger.info("Seeded demo candidate Elena Rostova with 2 completed evaluations, job, and memories.")
    return {
        "user_id": DEMO_USER_ID,
        "candidate_id": DEMO_CANDIDATE_ID,
        "job_id": DEMO_JOB_ID,
        "session_ids": [DEMO_SESSION_1_ID, DEMO_SESSION_2_ID],
        "evaluation_ids": [DEMO_EVAL_1_ID, DEMO_EVAL_2_ID],
    }
