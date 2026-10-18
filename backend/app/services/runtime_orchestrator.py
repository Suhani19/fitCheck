from __future__ import annotations

import logging
import os
from typing import Any
import uuid

from app.domain.schemas import (
    DEFAULT_SIMULATION_DISCLAIMER,
    DifficultyMode,
    EvaluationResponse,
    InterviewSessionPlan,
)
from app.services.agora import AgoraService
from app.services.agora_token import AgoraTokenService
from app.services.evaluation_engine import EvaluationEngineService
from app.services.interview_planner import InterviewPlannerService

logger = logging.getLogger(__name__)


class FitCheckRuntimeService:
    """Manages the lifecycle of real-time FitCheck interviews with Agora and Gemini Live."""

    def __init__(
        self,
        planner_service: InterviewPlannerService | None = None,
        evaluation_service: EvaluationEngineService | None = None,
    ) -> None:
        self.planner = planner_service or InterviewPlannerService()
        self.evaluator = evaluation_service or EvaluationEngineService()
        self.token_service = AgoraTokenService()

    def compile_runtime_prompt(
        self,
        candidate_data: dict[str, Any],
        job_data: dict[str, Any],
        interviewer_data: dict[str, Any],
        session_plan: InterviewSessionPlan,
        memories: list[dict[str, Any]] | None = None,
    ) -> str:
        """Compiles an adaptive, persona-grounded system instruction prompt for Gemini Live."""
        candidate_name = candidate_data.get("full_name", "Candidate")
        skills = ", ".join(candidate_data.get("skills") or [])
        projects = candidate_data.get("projects") or []
        experience = candidate_data.get("work_experience") or []

        projects_str = "\n".join(
            f"  * {p.get('name')}: {p.get('description', '')} (Tech: {', '.join(p.get('technologies') or [])})"
            for p in projects[:3]
        ) or "  * None listed"

        experience_str = "\n".join(
            f"  * {w.get('role')} at {w.get('company')}: {w.get('description', '')}"
            for w in experience[:3]
        ) or "  * None listed"

        job_title = job_data.get("title", "Software Engineer")
        seniority = job_data.get("seniority", "Senior")

        competencies_str = "\n".join(
            f"  * {cp.name}: {cp.planned_question} (Guidance: {cp.follow_up_guidance})"
            for cp in session_plan.competency_plans
        )

        diff = session_plan.difficulty_config

        memories_section = ""
        if memories and len(memories) > 0:
            mem_items = "\n".join(
                f"  * [{m.get('category', 'fact')}] {m.get('content', '')}"
                for m in memories
            )
            memories_section = f"""
CANDIDATE PRACTICE MEMORY & HISTORICAL CONTEXT:
The following are durable facts and verified milestones remembered from previous practice simulations with this candidate:
{mem_items}
Guidance on Candidate Memory:
- Naturally reference or follow up on these concepts when probing technical depth, without explicitly saying an AI recorded it.
- Verify whether the candidate can defend or expand on previously demonstrated topics.
"""

        prompt = f"""You are {interviewer_data.get('name', 'Alex')}, a {interviewer_data.get('title', 'Staff Engineer')} conducting an interview simulation for FitCheck.
Company context: {interviewer_data.get('company_context', 'Modern Tech Team')}
Questioning style: {interviewer_data.get('questioning_style', 'conversational')}

DISCLAIMER: {DEFAULT_SIMULATION_DISCLAIMER}

TARGET ROLE:
{job_title} ({seniority})
Job Description Summary: {job_data.get('description', '')[:500]}

CANDIDATE YOU ARE INTERVIEWING:
Name: {candidate_name}
Headline: {candidate_data.get('headline', '')}
Skills: {skills}
Verified Projects:
{projects_str}
Work History:
{experience_str}
{memories_section}
DIFFICULTY MODE: {diff.difficulty.upper()}
Tone: {diff.tone}
Probing Intensity: {diff.probing_intensity}
Hint Policy: {diff.hint_policy}
Depth Level: {diff.depth_level}
Expectation: {diff.expected_evidence_bar}

INTERVIEW OBJECTIVES & COMPETENCY PLAN:
{competencies_str}

CONVERSATIONAL RULES FOR LIVE AUDIO:
1. Speak in concise, natural spoken sentences (1-3 sentences per turn). Avoid long lectures or bulleted lists.
2. Begin with this opening question: "{session_plan.opening_question}"
3. Ground your questions in the candidate's actual projects and experience. Do NOT invent past companies or projects.
4. If candidate answers are vague or brief, request concrete examples and metrics.
5. In {diff.difficulty} mode, strictly adhere to the hint policy: {diff.hint_policy}.
6. When wrapping up, invite candidate questions about the team or role.
"""
        return prompt.strip()

    def start_session(
        self,
        session_id: str,
        candidate_data: dict[str, Any],
        job_data: dict[str, Any],
        interviewer_data: dict[str, Any],
        session_plan: InterviewSessionPlan,
        remote_uid: int = 1001,
        memories: list[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        """Provisions an Agora RTC channel and attempts to launch the Cloud Agent."""
        channel = f"fitcheck-{session_id}"
        rtc_token = self.token_service.generate_rtc_token(channel=channel, uid=remote_uid)
        app_id = os.getenv("AGORA_APP_ID", "")
        agent_id = None

        # Build compiled runtime prompt
        system_prompt = self.compile_runtime_prompt(
            candidate_data=candidate_data,
            job_data=job_data,
            interviewer_data=interviewer_data,
            session_plan=session_plan,
            memories=memories,
        )

        # Attempt to provision Agora Cloud Agent if Agora credentials are present
        agora_app_id = os.getenv("AGORA_APP_ID")
        gemini_api_key = os.getenv("GEMINI_API_KEY")

        if agora_app_id and gemini_api_key and os.getenv("AGORA_APP_CERTIFICATE"):
            try:
                from agora_agent.agentkit.agent import Agent
                from agora_agent.agentkit.vendors import GeminiLive
                from agora_agent.types.mllm_turn_detection import MllmTurnDetection
                from agora_agent.types.mllm_turn_detection_agora_vad_config import (
                    MllmTurnDetectionAgoraVadConfig,
                )

                agora_svc = AgoraService()
                voice_id = interviewer_data.get("voice_id", "Puck")

                turn_detection = MllmTurnDetection(
                    mode="agora_vad",
                    agora_vad_config=MllmTurnDetectionAgoraVadConfig(
                        interrupt_duration_ms=160,
                        prefix_padding_ms=800,
                        silence_duration_ms=640,
                        threshold=0.5,
                    ),
                )

                gemini_live = GeminiLive(
                    api_key=gemini_api_key,
                    model="models/gemini-3.8-live",
                    instructions=system_prompt,
                    voice=voice_id,
                    language_codes=["en-US"],
                    greeting_message=session_plan.opening_question,
                    input_modalities=["audio"],
                    output_modalities=["audio"],
                    transcribe_agent=True,
                    transcribe_user=True,
                    turn_detection=turn_detection,
                )

                agent = Agent(agora_svc.client, greeting=session_plan.opening_question).with_mllm(gemini_live)
                agent_session = agent.create_session(
                    channel=channel,
                    agent_uid="0",
                    remote_uids=[str(remote_uid)],
                    name=f"fitcheck-{session_id}",
                    idle_timeout=120,
                    debug=True,
                )
                agent_id = agent_session.start()
                logger.info("[RUNTIME] Provisioned Agora agent '%s' for session '%s'", agent_id, session_id)
            except Exception as exc:
                logger.warning("[RUNTIME] Agora Cloud Agent start deferred or mocked: %s", exc)

        agent_status = "active" if agent_id else "standby"

        return {
            "channel": channel,
            "agent_id": agent_id,
            "agent_status": agent_status,
            "rtc_token": rtc_token,
            "app_id": app_id,
            "compiled_prompt": system_prompt,
        }

    async def end_session_and_evaluate(
        self,
        session_id: str,
        user_id: str,
        transcript: list[dict[str, Any]],
        rubric_competencies: list[dict[str, Any]],
        difficulty: str = DifficultyMode.REALISTIC,
        agent_id: str | None = None,
    ) -> EvaluationResponse:
        """Collects turns (including Agora fallback), terminates session, and runs evidence-backed evaluation."""
        turns = list(transcript)

        # Fallback to Agora agent history if client turns are empty
        if not turns and agent_id:
            try:
                agora_svc = AgoraService()
                history_resp = agora_svc.client.agents.get_history(
                    appid=agora_svc.app_id,
                    agent_id=agent_id,
                )
                if history_resp and history_resp.contents:
                    for item in history_resp.contents:
                        if item.content and item.content.strip():
                            role = "candidate" if item.role == "user" else "interviewer"
                            turns.append({"role": role, "text": item.content.strip(), "turn_index": len(turns)})
                    logger.info("[RUNTIME] Retrieved %d turns from Agora agent history fallback", len(turns))
            except Exception as exc:
                logger.warning("[RUNTIME] Agora agent history query failed: %s", exc)

        evaluation = await self.evaluator.evaluate_interview(
            session_id=session_id,
            user_id=user_id,
            transcript=turns,
            rubric_competencies=rubric_competencies,
            difficulty=difficulty,
        )
        return evaluation

