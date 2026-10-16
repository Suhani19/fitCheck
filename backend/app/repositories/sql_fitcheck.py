from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
import uuid

from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.db.models import (
    CandidateModel,
    InterviewEvaluationModel,
    InterviewerModel,
    InterviewSessionModel,
    JobModel,
    CandidatePracticeMemoryModel,
    UserModel,
)
from app.repositories.fitcheck_base import (
    CandidateRepository,
    EvaluationRepository,
    InterviewerRepository,
    InterviewSessionRepository,
    JobRepository,
    UserRepository,
)


class SQLUserRepository(UserRepository):
    def __init__(self, db: Session) -> None:
        self.db = db

    def get(self, user_id: str) -> UserModel | None:
        return self.db.query(UserModel).filter(UserModel.id == user_id).first()

    def get_or_create(self, user_id: str, email: str | None = None, display_name: str | None = None) -> UserModel:
        user = self.get(user_id)
        if not user:
            user = UserModel(id=user_id, email=email, display_name=display_name)
            self.db.add(user)
            self.db.commit()
            self.db.refresh(user)
        return user


class SQLCandidateRepository(CandidateRepository):
    def __init__(self, db: Session) -> None:
        self.db = db

    def create(self, user_id: str, candidate_data: dict[str, Any]) -> CandidateModel:
        cid = candidate_data.get("id") or f"cand-{uuid.uuid4().hex[:8]}"
        candidate = CandidateModel(
            id=cid,
            user_id=user_id,
            full_name=candidate_data["full_name"],
            headline=candidate_data.get("headline"),
            resume_text=candidate_data.get("resume_text"),
            raw_resume_filename=candidate_data.get("raw_resume_filename"),
            skills=candidate_data.get("skills") or [],
            work_experience=candidate_data.get("work_experience") or [],
            projects=candidate_data.get("projects") or [],
            education=candidate_data.get("education") or [],
            github_username=candidate_data.get("github_username"),
            github_summary=candidate_data.get("github_summary") or {},
        )
        self.db.add(candidate)
        self.db.commit()
        self.db.refresh(candidate)
        return candidate

    def get(self, candidate_id: str, user_id: str) -> CandidateModel | None:
        return (
            self.db.query(CandidateModel)
            .filter(CandidateModel.id == candidate_id, CandidateModel.user_id == user_id)
            .first()
        )

    def list(self, user_id: str) -> list[CandidateModel]:
        return (
            self.db.query(CandidateModel)
            .filter(CandidateModel.user_id == user_id)
            .order_by(CandidateModel.created_at.desc())
            .all()
        )

    def update(self, candidate_id: str, user_id: str, candidate_data: dict[str, Any]) -> CandidateModel | None:
        candidate = self.get(candidate_id, user_id)
        if not candidate:
            return None
        for key, value in candidate_data.items():
            if hasattr(candidate, key) and key not in ("id", "user_id", "created_at"):
                setattr(candidate, key, value)
        candidate.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(candidate)
        return candidate

    def delete(self, candidate_id: str, user_id: str) -> bool:
        candidate = self.get(candidate_id, user_id)
        if not candidate:
            return False
        self.db.delete(candidate)
        self.db.commit()
        return True


class SQLJobRepository(JobRepository):
    def __init__(self, db: Session) -> None:
        self.db = db

    def create(self, user_id: str, job_data: dict[str, Any]) -> JobModel:
        jid = job_data.get("id") or f"job-{uuid.uuid4().hex[:8]}"
        job = JobModel(
            id=jid,
            user_id=user_id,
            title=job_data["title"],
            seniority=job_data.get("seniority", "senior"),
            description=job_data["description"],
            required_skills=job_data.get("required_skills") or [],
            competencies=job_data.get("competencies") or [],
        )
        self.db.add(job)
        self.db.commit()
        self.db.refresh(job)
        return job

    def get(self, job_id: str, user_id: str) -> JobModel | None:
        return (
            self.db.query(JobModel)
            .filter(JobModel.id == job_id, JobModel.user_id == user_id)
            .first()
        )

    def list(self, user_id: str) -> list[JobModel]:
        return (
            self.db.query(JobModel)
            .filter(JobModel.user_id == user_id)
            .order_by(JobModel.created_at.desc())
            .all()
        )

    def update(self, job_id: str, user_id: str, job_data: dict[str, Any]) -> JobModel | None:
        job = self.get(job_id, user_id)
        if not job:
            return None
        for key, value in job_data.items():
            if hasattr(job, key) and key not in ("id", "user_id", "created_at"):
                setattr(job, key, value)
        job.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(job)
        return job

    def delete(self, job_id: str, user_id: str) -> bool:
        job = self.get(job_id, user_id)
        if not job:
            return False
        self.db.delete(job)
        self.db.commit()
        return True


class SQLInterviewerRepository(InterviewerRepository):
    def __init__(self, db: Session) -> None:
        self.db = db

    def create(self, user_id: str, interviewer_data: dict[str, Any]) -> InterviewerModel:
        iid = interviewer_data.get("id") or f"int-{uuid.uuid4().hex[:8]}"
        interviewer = InterviewerModel(
            id=iid,
            user_id=user_id,
            name=interviewer_data["name"],
            title=interviewer_data["title"],
            bio=interviewer_data.get("bio"),
            company_context=interviewer_data.get("company_context"),
            questioning_style=interviewer_data.get("questioning_style", "conversational"),
            voice_id=interviewer_data.get("voice_id", "Puck"),
            is_preset=interviewer_data.get("is_preset", False),
            provenance=interviewer_data.get("provenance") or {},
        )
        self.db.add(interviewer)
        self.db.commit()
        self.db.refresh(interviewer)
        return interviewer

    def get(self, interviewer_id: str, user_id: str | None = None) -> InterviewerModel | None:
        alias_map = {
            "int-marcus": "marcus-arch-001",
            "int-sarah": "sarah-em-001",
            "int-alex": "alex-lead-001",
        }
        target_id = alias_map.get(interviewer_id, interviewer_id)
        query = self.db.query(InterviewerModel).filter(InterviewerModel.id == target_id)
        if user_id is not None:
            query = query.filter(or_(InterviewerModel.is_preset.is_(True), InterviewerModel.user_id == user_id))
        result = query.first()
        if not result and target_id in ("sarah-em-001", "marcus-arch-001", "alex-lead-001"):
            from app.db.seed_presets import seed_interviewer_presets
            seed_interviewer_presets(self.db)
            result = query.first()
        return result

    def list_presets(self) -> list[InterviewerModel]:
        presets = self.db.query(InterviewerModel).filter(InterviewerModel.is_preset.is_(True)).all()
        if not presets:
            from app.db.seed_presets import seed_interviewer_presets
            seed_interviewer_presets(self.db)
            presets = self.db.query(InterviewerModel).filter(InterviewerModel.is_preset.is_(True)).all()
        return presets

    def list(self, user_id: str) -> list[InterviewerModel]:
        presets = self.db.query(InterviewerModel).filter(InterviewerModel.is_preset.is_(True)).all()
        if not presets:
            from app.db.seed_presets import seed_interviewer_presets
            seed_interviewer_presets(self.db)
        return (
            self.db.query(InterviewerModel)
            .filter(or_(InterviewerModel.is_preset.is_(True), InterviewerModel.user_id == user_id))
            .order_by(InterviewerModel.is_preset.desc(), InterviewerModel.created_at.desc())
            .all()
        )

    def update(self, interviewer_id: str, user_id: str, interviewer_data: dict[str, Any]) -> InterviewerModel | None:
        interviewer = (
            self.db.query(InterviewerModel)
            .filter(
                InterviewerModel.id == interviewer_id,
                InterviewerModel.user_id == user_id,
                InterviewerModel.is_preset.is_(False),
            )
            .first()
        )
        if not interviewer:
            return None
        for key, value in interviewer_data.items():
            if hasattr(interviewer, key) and key not in ("id", "user_id", "is_preset", "created_at"):
                setattr(interviewer, key, value)
        interviewer.updated_at = datetime.now(timezone.utc)
        self.db.commit()
        self.db.refresh(interviewer)
        return interviewer

    def delete(self, interviewer_id: str, user_id: str) -> bool:
        interviewer = (
            self.db.query(InterviewerModel)
            .filter(
                InterviewerModel.id == interviewer_id,
                InterviewerModel.user_id == user_id,
                InterviewerModel.is_preset.is_(False),
            )
            .first()
        )
        if not interviewer:
            return False
        self.db.delete(interviewer)
        self.db.commit()
        return True


class SQLInterviewSessionRepository(InterviewSessionRepository):
    def __init__(self, db: Session) -> None:
        self.db = db

    def create(self, user_id: str, session_data: dict[str, Any]) -> InterviewSessionModel:
        sid = session_data.get("id") or f"sess-{uuid.uuid4().hex[:10]}"
        session = InterviewSessionModel(
            id=sid,
            user_id=user_id,
            candidate_id=session_data["candidate_id"],
            job_id=session_data["job_id"],
            interviewer_id=session_data["interviewer_id"],
            difficulty=session_data.get("difficulty", "realistic"),
            status=session_data.get("status", "created"),
            channel=session_data["channel"],
            agent_id=session_data.get("agent_id"),
            session_plan=session_data.get("session_plan") or {},
            transcript=session_data.get("transcript") or [],
        )
        self.db.add(session)
        self.db.commit()
        self.db.refresh(session)
        return session

    def get(self, session_id: str, user_id: str) -> InterviewSessionModel | None:
        return (
            self.db.query(InterviewSessionModel)
            .filter(InterviewSessionModel.id == session_id, InterviewSessionModel.user_id == user_id)
            .first()
        )

    def list(self, user_id: str) -> list[InterviewSessionModel]:
        return (
            self.db.query(InterviewSessionModel)
            .filter(InterviewSessionModel.user_id == user_id)
            .order_by(InterviewSessionModel.started_at.desc())
            .all()
        )

    def update_transcript(self, session_id: str, user_id: str, transcript: list[dict[str, Any]]) -> bool:
        session = self.get(session_id, user_id)
        if not session:
            return False
        session.transcript = transcript
        self.db.commit()
        return True

    def end_session(self, session_id: str, user_id: str, transcript: list[dict[str, Any]] | None = None) -> InterviewSessionModel | None:
        session = self.get(session_id, user_id)
        if not session:
            return None
        session.status = "ended"
        session.ended_at = datetime.now(timezone.utc)
        if transcript is not None:
            session.transcript = transcript
        self.db.commit()
        self.db.refresh(session)
        return session


class SQLEvaluationRepository(EvaluationRepository):
    def __init__(self, db: Session) -> None:
        self.db = db

    def create(self, user_id: str, evaluation_data: dict[str, Any]) -> InterviewEvaluationModel:
        session_id = evaluation_data["session_id"]
        existing = (
            self.db.query(InterviewEvaluationModel)
            .filter(InterviewEvaluationModel.session_id == session_id, InterviewEvaluationModel.user_id == user_id)
            .first()
        )
        if existing:
            existing.overall_score = evaluation_data["overall_score"]
            existing.overall_recommendation = evaluation_data["overall_recommendation"]
            existing.summary_verdict = evaluation_data["summary_verdict"]
            existing.competency_scores = evaluation_data["competency_scores"]
            existing.observed_strengths = evaluation_data.get("observed_strengths") or []
            existing.technical_gaps = evaluation_data.get("technical_gaps") or []
            existing.preparation_recommendations = evaluation_data.get("preparation_recommendations") or []
            existing.human_review = evaluation_data.get("human_review")
            self.db.commit()
            self.db.refresh(existing)
            return existing

        eid = evaluation_data.get("id") or f"eval-{uuid.uuid4().hex[:10]}"
        evaluation = InterviewEvaluationModel(
            id=eid,
            session_id=session_id,
            user_id=user_id,
            overall_score=evaluation_data["overall_score"],
            overall_recommendation=evaluation_data["overall_recommendation"],
            summary_verdict=evaluation_data["summary_verdict"],
            competency_scores=evaluation_data["competency_scores"],
            observed_strengths=evaluation_data.get("observed_strengths") or [],
            technical_gaps=evaluation_data.get("technical_gaps") or [],
            preparation_recommendations=evaluation_data.get("preparation_recommendations") or [],
            human_review=evaluation_data.get("human_review"),
        )
        self.db.add(evaluation)
        self.db.commit()
        self.db.refresh(evaluation)
        return evaluation

    def get_by_session(self, session_id: str, user_id: str) -> InterviewEvaluationModel | None:
        return (
            self.db.query(InterviewEvaluationModel)
            .filter(InterviewEvaluationModel.session_id == session_id, InterviewEvaluationModel.user_id == user_id)
            .first()
        )

    def list(self, user_id: str) -> list[InterviewEvaluationModel]:
        return (
            self.db.query(InterviewEvaluationModel)
            .filter(InterviewEvaluationModel.user_id == user_id)
            .order_by(InterviewEvaluationModel.created_at.desc())
            .all()
        )


class SQLCandidateMemoryRepository:
    """Repository for candidate practice memory storage, retrieval, and deletion with strict user isolation."""

    def __init__(self, db: Session) -> None:
        self.db = db

    def create(self, user_id: str, memory_data: dict[str, Any]) -> CandidatePracticeMemoryModel:
        mid = memory_data.get("id") or str(uuid.uuid4())
        now_str = datetime.now(timezone.utc).isoformat()
        memory = CandidatePracticeMemoryModel(
            id=mid,
            character_id=memory_data.get("character_id") or "interviewer-general",
            user_id=user_id,
            session_id=memory_data.get("session_id"),
            content=memory_data["content"],
            category=memory_data.get("category", "fact"),
            importance=float(memory_data.get("importance", 0.7)),
            created_at=now_str,
            updated_at=now_str,
        )
        self.db.add(memory)
        self.db.commit()
        self.db.refresh(memory)
        return memory

    def list(self, user_id: str, limit: int = 50) -> list[CandidatePracticeMemoryModel]:
        return (
            self.db.query(CandidatePracticeMemoryModel)
            .filter(CandidatePracticeMemoryModel.user_id == user_id)
            .order_by(CandidatePracticeMemoryModel.importance.desc(), CandidatePracticeMemoryModel.created_at.desc())
            .limit(limit)
            .all()
        )

    def get(self, memory_id: str, user_id: str) -> CandidatePracticeMemoryModel | None:
        return (
            self.db.query(CandidatePracticeMemoryModel)
            .filter(CandidatePracticeMemoryModel.id == memory_id, CandidatePracticeMemoryModel.user_id == user_id)
            .first()
        )

    def delete(self, memory_id: str, user_id: str) -> bool:
        memory = self.get(memory_id, user_id)
        if not memory:
            return False
        self.db.delete(memory)
        self.db.commit()
        return True

    def clear(self, user_id: str) -> int:
        deleted_count = (
            self.db.query(CandidatePracticeMemoryModel)
            .filter(CandidatePracticeMemoryModel.user_id == user_id)
            .delete(synchronize_session=False)
        )
        self.db.commit()
        return deleted_count

