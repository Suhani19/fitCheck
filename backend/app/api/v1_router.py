from __future__ import annotations

import logging
import os
import uuid
from typing import Any
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

from app.core.auth import AuthenticatedUser, get_current_user
from app.db.database import get_db
from app.domain.schemas import (
    CandidateCreateRequest,
    CandidateMemoryClearResponse,
    CandidateMemoryResponse,
    CandidateResponse,
    CandidateUpdateRequest,
    EndInterviewSessionRequest,
    EvaluationResponse,
    InterviewerCreateRequest,
    InterviewerPersonalizeRequest,
    InterviewerResponse,
    InterviewerUpdateRequest,
    InterviewSessionCreateRequest,
    InterviewSessionPlan,
    InterviewSessionResponse,
    JobCreateRequest,
    JobResponse,
    JobUpdateRequest,
    ResumeExtractionResult,
    ResumeTextInputRequest,
    RubricGenerationRequest,
    RubricGenerationResponse,
)
from app.repositories.sql_fitcheck import (
    SQLCandidateMemoryRepository,
    SQLCandidateRepository,
    SQLEvaluationRepository,
    SQLInterviewerRepository,
    SQLInterviewSessionRepository,
    SQLJobRepository,
)
from app.services.agora_token import AgoraTokenService
from app.services.interview_planner import InterviewPlannerService
from app.services.interviewer_personalizer import InterviewerPersonalizerService
from app.services.resume_extractor import ResumeExtractorService
from app.services.rubric_generator import RubricGeneratorService
from app.services.runtime_orchestrator import FitCheckRuntimeService

router = APIRouter(prefix="/api/v1")


# ---------------------------------------------------------------------------
# Workstream 1: Candidates & Resume Ingestion
# ---------------------------------------------------------------------------


@router.post("/candidates", response_model=CandidateResponse, status_code=status.HTTP_201_CREATED)
def create_candidate(
    request: CandidateCreateRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLCandidateRepository(db)
    cand = repo.create(current_user.uid, request.model_dump())
    return cand


@router.get("/candidates", response_model=list[CandidateResponse])
def list_candidates(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLCandidateRepository(db)
    return repo.list(current_user.uid)


@router.get("/candidates/{candidate_id}", response_model=CandidateResponse)
def get_candidate(
    candidate_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLCandidateRepository(db)
    cand = repo.get(candidate_id, current_user.uid)
    if not cand:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Candidate '{candidate_id}' not found.",
        )
    return cand


@router.put("/candidates/{candidate_id}", response_model=CandidateResponse)
def update_candidate(
    candidate_id: str,
    request: CandidateUpdateRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLCandidateRepository(db)
    updated = repo.update(candidate_id, current_user.uid, request.model_dump(exclude_unset=True))
    if not updated:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Candidate '{candidate_id}' not found.",
        )
    return updated


@router.delete("/candidates/{candidate_id}")
def delete_candidate(
    candidate_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLCandidateRepository(db)
    deleted = repo.delete(candidate_id, current_user.uid)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Candidate '{candidate_id}' not found.",
        )
    return {"status": "deleted", "candidate_id": candidate_id}


# ---------------------------------------------------------------------------
# Candidate Practice Memory Privacy & GDPR Controls
# ---------------------------------------------------------------------------


@router.get("/candidate/memories", response_model=list[CandidateMemoryResponse])
def list_candidate_memories(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Retrieves durable practice memories recorded for the authenticated candidate."""
    repo = SQLCandidateMemoryRepository(db)
    memories = repo.list(current_user.uid)
    return [
        CandidateMemoryResponse(
            id=m.id,
            content=m.content,
            category=m.category,
            importance=m.importance,
            created_at=m.created_at,
        )
        for m in memories
    ]


@router.delete("/candidate/memories/{memory_id}")
def delete_candidate_memory(
    memory_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Deletes a specific memory belonging to the authenticated candidate."""
    repo = SQLCandidateMemoryRepository(db)
    deleted = repo.delete(memory_id, current_user.uid)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Memory '{memory_id}' not found.",
        )
    return {"status": "deleted", "memory_id": memory_id}


@router.delete("/candidate/memories", response_model=CandidateMemoryClearResponse)
def clear_all_candidate_memories(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Purges all practice memories for the authenticated candidate (Right to be Forgotten)."""
    repo = SQLCandidateMemoryRepository(db)
    deleted_count = repo.clear(current_user.uid)
    return CandidateMemoryClearResponse(deleted_count=deleted_count, status="cleared")


@router.post("/candidates/upload-resume", response_model=ResumeExtractionResult)
async def upload_and_extract_resume(
    file: UploadFile = File(...),
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """Parses and extracts structured data from an uploaded resume file (PDF or text)."""
    service = ResumeExtractorService()
    try:
        content = await file.read()
        raw_text = service.extract_text_from_file(
            content=content,
            filename=file.filename or "resume.pdf",
            content_type=file.content_type,
        )
        extracted = await service.extract_structured_data(raw_text)
        return extracted
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process resume: {str(e)}",
        )


@router.post("/candidates/parse-text", response_model=ResumeExtractionResult)
async def parse_resume_text(
    request: ResumeTextInputRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """Extracts structured candidate data from directly pasted resume text."""
    service = ResumeExtractorService()
    try:
        extracted = await service.extract_structured_data(request.text)
        return extracted
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/candidates/{candidate_id}/upload-resume", response_model=CandidateResponse)
async def attach_resume_to_candidate(
    candidate_id: str,
    file: UploadFile = File(...),
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Uploads resume and updates an existing candidate profile with extracted data."""
    repo = SQLCandidateRepository(db)
    cand = repo.get(candidate_id, current_user.uid)
    if not cand:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Candidate '{candidate_id}' not found.",
        )

    service = ResumeExtractorService()
    try:
        content = await file.read()
        filename = file.filename or "resume.pdf"
        raw_text = service.extract_text_from_file(
            content=content,
            filename=filename,
            content_type=file.content_type,
        )
        extracted = await service.extract_structured_data(raw_text)

        update_data = {
            "resume_text": raw_text,
            "raw_resume_filename": filename,
            "skills": extracted.skills,
            "work_experience": [w.model_dump() for w in extracted.work_experience],
            "projects": [p.model_dump() for p in extracted.projects],
            "education": [e.model_dump() for e in extracted.education],
        }
        if extracted.headline and not cand.headline:
            update_data["headline"] = extracted.headline

        updated = repo.update(candidate_id, current_user.uid, update_data)
        return updated
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


# ---------------------------------------------------------------------------
# Workstream 2: Jobs & Competency Rubrics
# ---------------------------------------------------------------------------


@router.post("/jobs/generate-rubric", response_model=RubricGenerationResponse)
async def generate_competency_rubric(
    request: RubricGenerationRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """Assisted generation of 3-5 observable competency evaluation criteria for a role."""
    service = RubricGeneratorService()
    try:
        return await service.generate_rubric(request)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Rubric generation failed: {str(e)}",
        )


@router.post("/jobs", response_model=JobResponse, status_code=status.HTTP_201_CREATED)
def create_job(
    request: JobCreateRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLJobRepository(db)
    return repo.create(current_user.uid, request.model_dump())


@router.get("/jobs", response_model=list[JobResponse])
def list_jobs(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLJobRepository(db)
    return repo.list(current_user.uid)


@router.get("/jobs/{job_id}", response_model=JobResponse)
def get_job(
    job_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLJobRepository(db)
    job = repo.get(job_id, current_user.uid)
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job '{job_id}' not found.",
        )
    return job


@router.put("/jobs/{job_id}", response_model=JobResponse)
def update_job(
    job_id: str,
    request: JobUpdateRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLJobRepository(db)
    updated = repo.update(job_id, current_user.uid, request.model_dump(exclude_unset=True))
    if not updated:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job '{job_id}' not found.",
        )
    return updated


@router.delete("/jobs/{job_id}")
def delete_job(
    job_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLJobRepository(db)
    deleted = repo.delete(job_id, current_user.uid)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Job '{job_id}' not found.",
        )
    return {"status": "deleted", "job_id": job_id}


# ---------------------------------------------------------------------------
# Workstream 3: Interviewer Presets & Personalization
# ---------------------------------------------------------------------------


@router.post("/interviewers/personalize", response_model=InterviewerCreateRequest)
async def personalize_interviewer(
    request: InterviewerPersonalizeRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
):
    """Personalizes an interviewer persona while separating verified facts from inferred style."""
    service = InterviewerPersonalizerService()
    try:
        return await service.personalize_interviewer(request)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Interviewer personalization failed: {str(e)}",
        )


@router.get("/interviewers", response_model=list[InterviewerResponse])
def list_interviewers(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLInterviewerRepository(db)
    return repo.list(current_user.uid)


@router.post("/interviewers", response_model=InterviewerResponse, status_code=status.HTTP_201_CREATED)
def create_interviewer(
    request: InterviewerCreateRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLInterviewerRepository(db)
    data = request.model_dump()
    data["is_preset"] = False
    return repo.create(current_user.uid, data)


@router.get("/interviewers/{interviewer_id}", response_model=InterviewerResponse)
def get_interviewer(
    interviewer_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLInterviewerRepository(db)
    interviewer = repo.get(interviewer_id, current_user.uid)
    if not interviewer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Interviewer '{interviewer_id}' not found.",
        )
    return interviewer


@router.put("/interviewers/{interviewer_id}", response_model=InterviewerResponse)
def update_interviewer(
    interviewer_id: str,
    request: InterviewerUpdateRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLInterviewerRepository(db)
    updated = repo.update(interviewer_id, current_user.uid, request.model_dump(exclude_unset=True))
    if not updated:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Interviewer '{interviewer_id}' not found or cannot edit presets.",
        )
    return updated


@router.delete("/interviewers/{interviewer_id}")
def delete_interviewer(
    interviewer_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    repo = SQLInterviewerRepository(db)
    deleted = repo.delete(interviewer_id, current_user.uid)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Interviewer '{interviewer_id}' not found or cannot delete preset.",
        )
    return {"status": "deleted", "interviewer_id": interviewer_id}


# ---------------------------------------------------------------------------
# Sessions & Evaluations (Phase 3 Orchestration & Evaluation Integration)
# ---------------------------------------------------------------------------


@router.post("/sessions", response_model=InterviewSessionResponse, status_code=status.HTTP_201_CREATED)
async def create_interview_session(
    request: InterviewSessionCreateRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    cand_repo = SQLCandidateRepository(db)
    candidate = cand_repo.get(request.candidate_id, current_user.uid)
    if not candidate:
        raise HTTPException(status_code=404, detail="Candidate not found.")

    job_repo = SQLJobRepository(db)
    is_general_practice = request.job_id in ("general-practice", "default", "none", "job-general-eng")
    if is_general_practice:
        job = job_repo.get("job-general-eng", current_user.uid)
        if not job:
            job = job_repo.create(
                current_user.uid,
                {
                    "id": "job-general-eng",
                    "title": "General Software Engineering Practice",
                    "seniority": "Senior (L5/L6)",
                    "description": "General systems software engineering practice covering clean architecture, trade-offs, scalability, and code reasoning.",
                    "required_skills": ["System Design", "Problem Solving", "Clean Code"],
                    "competencies": [
                        {"name": "System Architecture & Trade-offs", "criteria": ["Defends architectural decisions", "Identifies trade-offs"]},
                        {"name": "Problem Solving & Execution", "criteria": ["Structured thought process", "Clear technical communication"]},
                    ],
                },
            )
    else:
        job = job_repo.get(request.job_id, current_user.uid)
        if not job:
            raise HTTPException(
                status_code=404,
                detail=f"Job not found: '{request.job_id}'. Please select a valid target job.",
            )

    int_repo = SQLInterviewerRepository(db)
    interviewer = int_repo.get(request.interviewer_id, current_user.uid)
    if not interviewer:
        raise HTTPException(
            status_code=404,
            detail=f"Interviewer '{request.interviewer_id}' not found. Please choose an active persona from the library.",
        )

    session_id = uuid.uuid4().hex[:10]

    # 1. Synthesize structured interview plan combining candidate, job, interviewer, and difficulty
    planner = InterviewPlannerService()
    candidate_dict = {
        "id": candidate.id,
        "full_name": candidate.full_name,
        "headline": candidate.headline,
        "skills": candidate.skills or [],
        "work_experience": candidate.work_experience or [],
        "projects": candidate.projects or [],
        "education": candidate.education or [],
    }
    job_dict = {
        "id": job.id,
        "title": job.title,
        "seniority": job.seniority,
        "description": job.description,
        "required_skills": job.required_skills or [],
        "competencies": job.competencies or [],
    }
    interviewer_dict = {
        "id": interviewer.id,
        "name": interviewer.name,
        "title": interviewer.title,
        "company_context": interviewer.company_context,
        "questioning_style": interviewer.questioning_style,
        "voice_id": interviewer.voice_id,
        "bio": interviewer.bio,
        "provenance": interviewer.provenance or {},
    }
    session_plan = await planner.generate_plan(
        candidate_data=candidate_dict,
        job_data=job_dict,
        interviewer_data=interviewer_dict,
        difficulty=request.difficulty,
    )

    # 2. Retrieve existing candidate practice memories
    mem_repo = SQLCandidateMemoryRepository(db)
    candidate_memories = mem_repo.list(current_user.uid, limit=8)
    memories_payload = [
        {"content": m.content, "category": m.category, "importance": m.importance}
        for m in candidate_memories
    ]

    # 3. Launch or provision runtime
    runtime_svc = FitCheckRuntimeService(planner_service=planner)
    runtime_info = runtime_svc.start_session(
        session_id=session_id,
        candidate_data=candidate_dict,
        job_data=job_dict,
        interviewer_data=interviewer_dict,
        session_plan=session_plan,
        remote_uid=1001,
        memories=memories_payload,
    )

    # 3. Persist session with session_plan
    sess_repo = SQLInterviewSessionRepository(db)
    session = sess_repo.create(
        user_id=current_user.uid,
        session_data={
            "id": session_id,
            "candidate_id": request.candidate_id,
            "job_id": request.job_id,
            "interviewer_id": request.interviewer_id,
            "difficulty": request.difficulty,
            "status": "active",
            "channel": runtime_info["channel"],
            "agent_id": runtime_info.get("agent_id"),
            "session_plan": session_plan.model_dump(),
        },
    )

    return InterviewSessionResponse(
        id=session.id,
        user_id=session.user_id,
        candidate_id=session.candidate_id,
        job_id=session.job_id,
        interviewer_id=session.interviewer_id,
        difficulty=session.difficulty,
        status=session.status,
        channel=session.channel,
        agent_id=session.agent_id,
        session_plan=session.session_plan,
        rtc_token=runtime_info.get("rtc_token"),
        app_id=runtime_info.get("app_id"),
        started_at=session.started_at,
        ended_at=session.ended_at,
    )


@router.get("/sessions", response_model=list[InterviewSessionResponse])
def list_interview_sessions(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    sess_repo = SQLInterviewSessionRepository(db)
    return sess_repo.list(current_user.uid)


@router.get("/sessions/{session_id}", response_model=InterviewSessionResponse)
def get_interview_session(
    session_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    sess_repo = SQLInterviewSessionRepository(db)
    sess = sess_repo.get(session_id, current_user.uid)
    if not sess:
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found.")
    return sess


@router.get("/sessions/{session_id}/plan", response_model=InterviewSessionPlan)
def get_session_plan(
    session_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Retrieves the calibrated session plan for an interview session."""
    sess_repo = SQLInterviewSessionRepository(db)
    sess = sess_repo.get(session_id, current_user.uid)
    if not sess or not sess.session_plan:
        raise HTTPException(status_code=404, detail=f"Plan for session '{session_id}' not found.")
    return sess.session_plan


@router.post("/sessions/{session_id}/next-question")
def get_next_adaptive_question(
    session_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Evaluates conversation history and returns the next adaptive question and stage transition."""
    from app.services.adaptive_orchestrator import AdaptiveInterviewOrchestrator

    sess_repo = SQLInterviewSessionRepository(db)
    session = sess_repo.get(session_id, current_user.uid)
    if not session or not session.session_plan:
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found.")

    plan = InterviewSessionPlan.model_validate(session.session_plan)
    orchestrator = AdaptiveInterviewOrchestrator(plan)
    transcript = session.transcript or []
    decision = orchestrator.evaluate_stage_transition(transcript)
    next_q = orchestrator.select_next_question(transcript, current_stage=decision.next_stage)
    coverage = orchestrator.track_competency_coverage(transcript)

    return {
        "question": next_q.model_dump(),
        "stage_decision": decision.model_dump(),
        "competency_coverage": {k: v.model_dump() for k, v in coverage.items()},
    }


@router.post("/sessions/{session_id}/end", response_model=InterviewSessionResponse)
async def end_interview_session(
    session_id: str,
    request: EndInterviewSessionRequest,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    sess_repo = SQLInterviewSessionRepository(db)
    session = sess_repo.get(session_id, current_user.uid)
    if not session:
        raise HTTPException(status_code=404, detail=f"Session '{session_id}' not found.")

    eval_repo = SQLEvaluationRepository(db)
    existing_eval = eval_repo.get_by_session(session_id, current_user.uid)
    if session.status == "ended" and existing_eval:
        logger.info("[SESSION] Session '%s' already ended and evaluated. Returning existing session.", session_id)
        return session

    sess = sess_repo.end_session(session_id, current_user.uid, transcript=request.transcript)

    # 1. Retrieve job competencies for evaluation
    job_repo = SQLJobRepository(db)
    job = job_repo.get(session.job_id, current_user.uid)
    rubric_competencies = job.competencies if job else []

    # 2. Run evidence-backed evaluation
    runtime_svc = FitCheckRuntimeService()
    evaluation_report = await runtime_svc.end_session_and_evaluate(
        session_id=session_id,
        user_id=current_user.uid,
        transcript=sess.transcript or [],
        rubric_competencies=rubric_competencies,
        difficulty=sess.difficulty,
        agent_id=sess.agent_id,
    )

    # 3. Persist evaluation report if not already existing
    if not existing_eval:
        eval_repo.create(
            user_id=current_user.uid,
            evaluation_data={
                "id": evaluation_report.id,
                "session_id": session_id,
                "overall_score": evaluation_report.overall_score,
                "overall_recommendation": evaluation_report.overall_recommendation,
                "summary_verdict": evaluation_report.summary_verdict,
                "competency_scores": evaluation_report.competency_scores,
                "observed_strengths": evaluation_report.observed_strengths,
                "technical_gaps": evaluation_report.technical_gaps,
                "preparation_recommendations": evaluation_report.preparation_recommendations,
                "human_review": evaluation_report.human_review,
            },
        )

    # 4. Extract durable candidate facts and projects into candidate practice memory
    if sess.transcript:
        try:
            from app.models.character import Behavior, Personality, Story, VoiceProfile, InterviewerPersona
            from app.models.session import TranscriptTurn
            from app.services.memory_extractor import MemoryExtractor

            turns = [
                TranscriptTurn(role=t.get("role", "user"), text=t.get("text", ""))
                for t in sess.transcript
                if isinstance(t, dict) and t.get("text")
            ]
            if turns:
                int_repo = SQLInterviewerRepository(db)
                interviewer = int_repo.get(session.interviewer_id, current_user.uid)
                interviewer_name = interviewer.name if interviewer else "Interviewer"
                
                char_mock = InterviewerPersona(
                    id=session.interviewer_id,
                    user_id=current_user.uid,
                    name=interviewer_name,
                    role="Technical Interviewer",
                    appearance="Professional",
                    personality=Personality(traits=["Objective", "Technical"]),
                    behavior=Behavior(),
                    voice=VoiceProfile(),
                    story=Story(),
                )
                extractor = MemoryExtractor()
                extracted_memories, _ = await extractor.extract_session_data(turns, char_mock)
                if extracted_memories:
                    mem_repo = SQLCandidateMemoryRepository(db)
                    for em in extracted_memories:
                        mem_repo.create(
                            current_user.uid,
                            {
                                "character_id": session.interviewer_id,
                                "session_id": session_id,
                                "content": em.content,
                                "category": em.category,
                                "importance": em.importance,
                            },
                        )
        except Exception as mem_exc:
            logger.warning("[MEMORY] Candidate memory extraction skipped/failed: %s", mem_exc)

    return sess


@router.get("/evaluations/{session_id}", response_model=EvaluationResponse)
def get_evaluation(
    session_id: str,
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    eval_repo = SQLEvaluationRepository(db)
    evaluation = eval_repo.get_by_session(session_id, current_user.uid)
    if not evaluation:
        raise HTTPException(status_code=404, detail=f"Evaluation for session '{session_id}' not found.")
    return evaluation


@router.get("/evaluations", response_model=list[EvaluationResponse])
def list_evaluations(
    current_user: AuthenticatedUser = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    eval_repo = SQLEvaluationRepository(db)
    return eval_repo.list(current_user.uid)
