from datetime import datetime, timezone
from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Index,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.types import JSON
from sqlalchemy.orm import relationship

from app.db.database import Base

# Universal JSON type that works on both PostgreSQL (JSONB) and SQLite (JSON)
JsonType = JSON().with_variant(JSONB(), "postgresql")


class UserModel(Base):
    """User account model backed by Firebase Authentication."""

    __tablename__ = "users"

    id = Column(String(128), primary_key=True)  # Firebase UID
    email = Column(String(255), unique=True, nullable=True, index=True)
    display_name = Column(String(255), nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )

    candidates = relationship("CandidateModel", back_populates="user", cascade="all, delete-orphan")
    jobs = relationship("JobModel", back_populates="user", cascade="all, delete-orphan")
    interview_sessions = relationship("InterviewSessionModel", back_populates="user", cascade="all, delete-orphan")


class CandidateModel(Base):
    """Candidate profile containing resume, skills, and work history."""

    __tablename__ = "candidates"

    id = Column(String(64), primary_key=True)
    user_id = Column(String(128), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    full_name = Column(String(255), nullable=False)
    headline = Column(String(255), nullable=True)
    resume_text = Column(Text, nullable=True)
    raw_resume_filename = Column(String(255), nullable=True)
    skills = Column(JsonType, nullable=True, default=list)
    work_experience = Column(JsonType, nullable=True, default=list)
    projects = Column(JsonType, nullable=True, default=list)
    education = Column(JsonType, nullable=True, default=list)
    github_username = Column(String(128), nullable=True)
    github_summary = Column(JsonType, nullable=True, default=dict)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )

    user = relationship("UserModel", back_populates="candidates")
    interview_sessions = relationship("InterviewSessionModel", back_populates="candidate", cascade="all, delete-orphan")


class JobModel(Base):
    """Job posting with description and evaluation competencies."""

    __tablename__ = "jobs"

    id = Column(String(64), primary_key=True)
    user_id = Column(String(128), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    title = Column(String(255), nullable=False)
    seniority = Column(String(64), nullable=False, default="senior")
    description = Column(Text, nullable=False)
    required_skills = Column(JsonType, nullable=True, default=list)
    competencies = Column(JsonType, nullable=True, default=list)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )

    user = relationship("UserModel", back_populates="jobs")
    interview_sessions = relationship("InterviewSessionModel", back_populates="job", cascade="all, delete-orphan")


class InterviewerModel(Base):
    """Interviewer persona (built-in preset or custom professional persona)."""

    __tablename__ = "interviewers"

    id = Column(String(64), primary_key=True)
    user_id = Column(String(128), ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    name = Column(String(255), nullable=False)
    title = Column(String(255), nullable=False)
    bio = Column(Text, nullable=True)
    company_context = Column(Text, nullable=True)
    questioning_style = Column(String(64), nullable=False, default="conversational")
    voice_id = Column(String(64), nullable=False, default="Puck")
    is_preset = Column(Boolean, default=False, nullable=False)
    provenance = Column(JsonType, nullable=True, default=dict)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )

    interview_sessions = relationship("InterviewSessionModel", back_populates="interviewer", cascade="all, delete-orphan")


class InterviewSessionModel(Base):
    """Real-time interview session record."""

    __tablename__ = "interview_sessions"

    id = Column(String(64), primary_key=True)
    user_id = Column(String(128), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    candidate_id = Column(String(64), ForeignKey("candidates.id", ondelete="CASCADE"), nullable=False, index=True)
    job_id = Column(String(64), ForeignKey("jobs.id", ondelete="CASCADE"), nullable=False, index=True)
    interviewer_id = Column(String(64), ForeignKey("interviewers.id", ondelete="CASCADE"), nullable=False, index=True)
    difficulty = Column(String(64), nullable=False, default="realistic")
    status = Column(String(64), nullable=False, default="created")
    channel = Column(String(128), nullable=False)
    agent_id = Column(String(128), nullable=True)
    session_plan = Column(JsonType, nullable=True, default=dict)
    transcript = Column(JsonType, nullable=True, default=list)
    started_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )
    ended_at = Column(DateTime(timezone=True), nullable=True)

    @property
    def agent_status(self) -> str:
        return "active" if self.agent_id else "standby"

    user = relationship("UserModel", back_populates="interview_sessions")
    candidate = relationship("CandidateModel", back_populates="interview_sessions")
    job = relationship("JobModel", back_populates="interview_sessions")
    interviewer = relationship("InterviewerModel", back_populates="interview_sessions")
    evaluation = relationship("InterviewEvaluationModel", back_populates="session", uselist=False, cascade="all, delete-orphan")


class InterviewEvaluationModel(Base):
    """Post-interview evaluation report with competency evidence citations."""

    __tablename__ = "interview_evaluations"

    id = Column(String(64), primary_key=True)
    session_id = Column(String(64), ForeignKey("interview_sessions.id", ondelete="CASCADE"), unique=True, nullable=False, index=True)
    user_id = Column(String(128), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    overall_score = Column(Float, nullable=False)
    overall_recommendation = Column(String(64), nullable=False)
    summary_verdict = Column(Text, nullable=False)
    competency_scores = Column(JsonType, nullable=False, default=list)
    observed_strengths = Column(JsonType, nullable=True, default=list)
    technical_gaps = Column(JsonType, nullable=True, default=list)
    preparation_recommendations = Column(JsonType, nullable=True, default=list)
    human_review = Column(JsonType, nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )

    session = relationship("InterviewSessionModel", back_populates="evaluation")


# Preserved Archived & Practice Memory Models


class ArchivedInterviewerModel(Base):
    __tablename__ = "archived_interviewers"

    id = Column(String(128), primary_key=True)
    name = Column(String(255), nullable=False)
    role = Column(String(255), nullable=False)
    data = Column(Text, nullable=False)
    deleted_at = Column(String(64), nullable=True)
    created_at = Column(String(64), nullable=True)
    updated_at = Column(String(64), nullable=True)


class ArchivedSessionModel(Base):
    __tablename__ = "archived_sessions"

    id = Column(String(128), primary_key=True)
    character_id = Column(String(128), nullable=False)
    user_id = Column(String(128), nullable=False)
    channel = Column(String(255), nullable=False)
    agent_id = Column(String(128), nullable=True)
    status = Column(String(64), nullable=False)
    started_at = Column(String(64), nullable=True)
    ended_at = Column(String(64), nullable=True)


class CandidatePracticeMemoryModel(Base):
    __tablename__ = "candidate_practice_memories"

    id = Column(String(128), primary_key=True)
    character_id = Column(String(128), nullable=False)
    user_id = Column(String(128), nullable=False)
    session_id = Column(String(128), nullable=True)
    content = Column(Text, nullable=False)
    category = Column(String(64), nullable=False)
    importance = Column(Float, nullable=False)
    created_at = Column(String(64), nullable=True)
    updated_at = Column(String(64), nullable=True)


class ArchivedRelationshipModel(Base):
    __tablename__ = "archived_relationships"

    character_id = Column(String(128), primary_key=True)
    user_id = Column(String(128), primary_key=True)
    relationship_score = Column(Float, nullable=False)
    trust = Column(Float, nullable=False)
    familiarity = Column(Float, nullable=False)
    affection = Column(Float, nullable=False)
    respect = Column(Float, nullable=False)
    tension = Column(Float, nullable=False)
    milestones = Column(Text, nullable=True)
    total_sessions = Column(Float, default=0)
    last_session_at = Column(String(64), nullable=True)
    created_at = Column(String(64), nullable=True)
    updated_at = Column(String(64), nullable=True)


class ArchivedMetadataModel(Base):
    __tablename__ = "archived_metadata"

    key = Column(String(128), primary_key=True)
    value = Column(Text, nullable=False)


