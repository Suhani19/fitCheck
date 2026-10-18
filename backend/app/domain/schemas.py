from __future__ import annotations

from datetime import datetime
from typing import Any
from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Candidate & Resume Ingestion Schemas
# ---------------------------------------------------------------------------


class WorkExperienceItem(BaseModel):
    company: str = Field(min_length=1)
    role: str = Field(min_length=1)
    start_date: str | None = None
    end_date: str | None = None
    description: str | None = None
    technologies: list[str] = Field(default_factory=list)


class ProjectItem(BaseModel):
    name: str = Field(min_length=1)
    description: str | None = None
    technologies: list[str] = Field(default_factory=list)
    url: str | None = None


class EducationItem(BaseModel):
    institution: str = Field(min_length=1)
    degree: str | None = None
    field_of_study: str | None = None
    graduation_year: str | None = None


class ResumeExtractionResult(BaseModel):
    full_name: str | None = None
    headline: str | None = None
    skills: list[str] = Field(default_factory=list)
    work_experience: list[WorkExperienceItem] = Field(default_factory=list)
    projects: list[ProjectItem] = Field(default_factory=list)
    education: list[EducationItem] = Field(default_factory=list)
    raw_text_preview: str | None = None
    extraction_notes: str | None = None


class ResumeTextInputRequest(BaseModel):
    text: str = Field(min_length=10, description="Raw resume text")
    filename: str | None = "pasted_resume.txt"


class CandidateCreateRequest(BaseModel):
    full_name: str = Field(min_length=1)
    headline: str | None = None
    resume_text: str | None = None
    raw_resume_filename: str | None = None
    skills: list[str] = Field(default_factory=list)
    work_experience: list[dict[str, Any]] = Field(default_factory=list)
    projects: list[dict[str, Any]] = Field(default_factory=list)
    education: list[dict[str, Any]] = Field(default_factory=list)
    github_username: str | None = None


class CandidateUpdateRequest(BaseModel):
    full_name: str | None = None
    headline: str | None = None
    resume_text: str | None = None
    raw_resume_filename: str | None = None
    skills: list[str] | None = None
    work_experience: list[dict[str, Any]] | None = None
    projects: list[dict[str, Any]] | None = None
    education: list[dict[str, Any]] | None = None
    github_username: str | None = None


class CandidateResponse(BaseModel):
    id: str
    user_id: str
    full_name: str
    headline: str | None
    resume_text: str | None
    raw_resume_filename: str | None = None
    skills: list[str] | None = None
    work_experience: list[dict[str, Any]] | None = None
    projects: list[dict[str, Any]] | None = None
    education: list[dict[str, Any]] | None = None
    github_username: str | None = None
    github_summary: dict[str, Any] | None = None
    created_at: Any
    updated_at: Any


class CandidateMemoryResponse(BaseModel):
    id: str
    content: str
    category: str
    importance: float
    created_at: str | None = None


class CandidateMemoryClearResponse(BaseModel):
    deleted_count: int
    status: str = "cleared"


# ---------------------------------------------------------------------------
# Job & Competency Rubric Schemas
# ---------------------------------------------------------------------------


class CompetencyRubricItem(BaseModel):
    name: str = Field(min_length=1, description="Competency name, e.g. System Design")
    description: str = Field(min_length=1, description="Job-related relevance and definition")
    criteria: list[str] = Field(min_length=1, description="Observable evaluation criteria and scoring anchors")
    weight: float = Field(default=1.0, ge=0.0)


class RubricGenerationRequest(BaseModel):
    title: str = Field(min_length=1)
    description: str = Field(min_length=1)
    seniority: str = Field(default="senior")
    required_skills: list[str] = Field(default_factory=list)


class RubricGenerationResponse(BaseModel):
    competencies: list[CompetencyRubricItem]


class JobCreateRequest(BaseModel):
    title: str = Field(min_length=1)
    seniority: str = Field(default="senior")
    description: str = Field(min_length=1)
    required_skills: list[str] = Field(default_factory=list)
    competencies: list[dict[str, Any]] = Field(default_factory=list)


class JobUpdateRequest(BaseModel):
    title: str | None = None
    seniority: str | None = None
    description: str | None = None
    required_skills: list[str] | None = None
    competencies: list[dict[str, Any]] | None = None


class JobResponse(BaseModel):
    id: str
    user_id: str
    title: str
    seniority: str
    description: str
    required_skills: list[str] | None = None
    competencies: list[dict[str, Any]] | None = None
    created_at: Any
    updated_at: Any


# ---------------------------------------------------------------------------
# Interviewer & Provenance Schemas
# ---------------------------------------------------------------------------


class InterviewerFactProvenance(BaseModel):
    fact: str
    source_url: str | None = None
    source_type: str = "user_provided"  # user_provided, public_profile, organization
    retrieval_date: str | None = None
    verified: bool = True


DEFAULT_SIMULATION_DISCLAIMER = (
    "FitCheck provides an AI simulation for practice and preparation purposes, "
    "not the actual person's participation or endorsement."
)


class InterviewerProvenance(BaseModel):
    verified_facts: list[InterviewerFactProvenance] = Field(default_factory=list)
    inferred_style: dict[str, Any] = Field(default_factory=dict)
    disclaimer: str = DEFAULT_SIMULATION_DISCLAIMER


class InterviewerPersonalizeRequest(BaseModel):
    name: str = Field(min_length=1)
    title: str = Field(min_length=1)
    company_context: str | None = None
    public_profile_text: str | None = None
    public_url: str | None = None
    user_notes: str | None = None
    questioning_style: str = "conversational"
    voice_id: str = "Puck"


class InterviewerCreateRequest(BaseModel):
    name: str = Field(min_length=1)
    title: str = Field(min_length=1)
    bio: str | None = None
    company_context: str | None = None
    questioning_style: str = "conversational"
    voice_id: str = "Puck"
    provenance: dict[str, Any] = Field(default_factory=dict)


class InterviewerUpdateRequest(BaseModel):
    name: str | None = None
    title: str | None = None
    bio: str | None = None
    company_context: str | None = None
    questioning_style: str | None = None
    voice_id: str | None = None
    provenance: dict[str, Any] | None = None


class InterviewerResponse(BaseModel):
    id: str
    user_id: str | None
    name: str
    title: str
    bio: str | None = None
    company_context: str | None = None
    questioning_style: str
    voice_id: str
    is_preset: bool
    provenance: dict[str, Any] | None = None
    created_at: Any
    updated_at: Any


# ---------------------------------------------------------------------------
# Phase 3: Interview Planning, Difficulty & Orchestration Schemas
# ---------------------------------------------------------------------------


class DifficultyMode(str):
    LENIENT = "lenient"
    REALISTIC = "realistic"
    CHALLENGING = "challenging"
    EXPERT_STRESS = "expert_stress"


class InterviewStage(str):
    INTRODUCTION = "introduction"
    EXPERIENCE_DEEP_DIVE = "experience_deep_dive"
    TECHNICAL_ASSESSMENT = "technical_assessment"
    CANDIDATE_QUESTIONS = "candidate_questions"
    COMPLETED = "completed"


class DifficultyConfiguration(BaseModel):
    difficulty: str
    tone: str
    probing_intensity: str
    hint_policy: str
    depth_level: str
    expected_evidence_bar: str


class CompetencyPlanItem(BaseModel):
    name: str
    description: str
    target_stage: str
    planned_question: str
    follow_up_guidance: str
    observable_criteria: list[str] = Field(default_factory=list)
    weight: float = 1.0


class PlanStrategy(BaseModel):
    target_duration_minutes: int = 30
    stages: list[str] = Field(default_factory=lambda: [
        "introduction",
        "experience_deep_dive",
        "technical_assessment",
        "candidate_questions",
    ])
    early_exit_min_evidence_turns: int = 4


class InterviewSessionPlan(BaseModel):
    objectives: list[str] = Field(default_factory=list)
    difficulty: str = "realistic"
    difficulty_config: DifficultyConfiguration
    competency_plans: list[CompetencyPlanItem] = Field(default_factory=list)
    opening_question: str
    strategy: PlanStrategy = Field(default_factory=PlanStrategy)
    follow_up_rules: list[str] = Field(default_factory=list)
    completion_criteria: list[str] = Field(default_factory=list)


class CompetencyCoverageStatus(BaseModel):
    competency_name: str
    status: str = "unexplored"  # unexplored, in_progress, covered, insufficient_evidence
    evidence_count: int = 0
    key_observations: list[str] = Field(default_factory=list)


class StageTransitionDecision(BaseModel):
    current_stage: str
    next_stage: str
    should_transition: bool
    reason: str
    remaining_unexplored_competencies: list[str] = Field(default_factory=list)
    ready_for_early_completion: bool = False


class AdaptiveQuestionResult(BaseModel):
    question: str
    stage: str
    targeted_competency: str | None = None
    rationale: str
    is_follow_up: bool
    clarification_needed: bool = False
    difficulty_tone: str


class NextAdaptiveQuestionRequest(BaseModel):
    candidate_answer: str | None = None
    transcript_turns: list[dict[str, Any]] | None = None
    stage: str | None = None


class AppendTranscriptTurnRequest(BaseModel):
    role: str = Field(description="Turn speaker: 'candidate' or 'interviewer'")
    text: str = Field(description="Verbatim utterance text")
    turn_index: int | None = None
    stage: str | None = None
    metadata: dict[str, Any] | None = None


# ---------------------------------------------------------------------------
# Phase 3: Evidence-Backed Evaluation Schemas
# ---------------------------------------------------------------------------


class TranscriptEvidenceCitation(BaseModel):
    quote: str = Field(description="Exact quotation from the candidate's transcript turns")
    turn_index: int = Field(description="Index of the transcript turn containing the quote")
    speaker: str = "candidate"
    relevance: str = Field(description="Why this quotation evidences or disproves the competency")
    verified: bool = Field(default=True, description="Whether the quote was verified against actual transcript text")


class CompetencyEvaluationScore(BaseModel):
    competency_name: str
    score: float = Field(ge=0.0, le=5.0)
    weight: float = 1.0
    status: str = "evaluated"  # "evaluated" or "insufficient_evidence"
    criteria_met: list[str] = Field(default_factory=list)
    criteria_missed: list[str] = Field(default_factory=list)
    evidence_citations: list[TranscriptEvidenceCitation] = Field(default_factory=list)
    explanation: str


class InterviewSessionCreateRequest(BaseModel):
    candidate_id: str
    job_id: str
    interviewer_id: str
    difficulty: str = "realistic"


class InterviewSessionResponse(BaseModel):
    id: str
    user_id: str
    candidate_id: str
    job_id: str
    interviewer_id: str
    difficulty: str
    status: str
    channel: str
    agent_id: str | None = None
    agent_status: str = "standby"
    session_plan: dict[str, Any] | None = None
    rtc_token: str | None = None
    app_id: str | None = None
    started_at: Any
    ended_at: Any | None = None


class EndInterviewSessionRequest(BaseModel):
    transcript: list[dict[str, Any]] = Field(default_factory=list)


class EvaluationResponse(BaseModel):
    id: str
    session_id: str
    user_id: str
    overall_score: float
    overall_recommendation: str
    summary_verdict: str
    competency_scores: list[dict[str, Any]]
    observed_strengths: list[str] | None = None
    technical_gaps: list[str] | None = None
    insufficient_evidence: list[str] | None = None
    preparation_recommendations: list[str] | None = None
    human_review: dict[str, Any] | None = None
    created_at: Any
