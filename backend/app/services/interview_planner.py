from __future__ import annotations

import logging
import os
from typing import Any

from google import genai
from google.genai import types

from app.domain.schemas import (
    CompetencyPlanItem,
    DifficultyConfiguration,
    DifficultyMode,
    InterviewSessionPlan,
    InterviewStage,
    PlanStrategy,
)

logger = logging.getLogger(__name__)

DIFFICULTY_CONFIGURATIONS: dict[str, DifficultyConfiguration] = {
    DifficultyMode.LENIENT: DifficultyConfiguration(
        difficulty=DifficultyMode.LENIENT,
        tone="Warm, highly encouraging, and supportive. Emphasize psychological safety and collaborative problem solving.",
        probing_intensity="Gentle single-level inquiry. If the candidate struggles, rephrase gently and offer constructive guidance.",
        hint_policy="Provide supportive hints, leading questions, and options when the candidate feels stuck or uncertain.",
        depth_level="Focus on conceptual clarity, architectural foundations, and sound software engineering practices.",
        expected_evidence_bar="Reward foundational reasoning, clear communication, and willingness to learn.",
    ),
    DifficultyMode.REALISTIC: DifficultyConfiguration(
        difficulty=DifficultyMode.REALISTIC,
        tone="Professional, objective, balanced, and conversational. Standard industry hiring bar.",
        probing_intensity="Balanced follow-up (1-2 layers deep). Inquire into rationale, key trade-offs, and design alternatives.",
        hint_policy="Offer subtle high-level nudges only if directly requested by the candidate; otherwise allow candidate to lead.",
        depth_level="Production engineering depth: realistic scale, error handling, database choices, and latency trade-offs.",
        expected_evidence_bar="Expect well-justified decisions, role-appropriate depth, and awareness of common edge cases.",
    ),
    DifficultyMode.CHALLENGING: DifficultyConfiguration(
        difficulty=DifficultyMode.CHALLENGING,
        tone="Direct, analytical, rigorous, and skeptical. Actively scrutinize assumptions and architectural shortcuts.",
        probing_intensity="Deep multi-layer probing (2-3 layers deep). Push on boundary conditions, bottlenecks, and scale limits.",
        hint_policy="No unsolicited hints. If the candidate presents a naive design, introduce realistic production complications.",
        depth_level="Deep systems level: failure modes, concurrency, network partitions, memory/CPU bottlenecks, data integrity.",
        expected_evidence_bar="Requires precise technical vocabulary, quantitative trade-off analysis, and disaster recovery planning.",
    ),
    DifficultyMode.EXPERT_STRESS: DifficultyConfiguration(
        difficulty=DifficultyMode.EXPERT_STRESS,
        tone="Razor-sharp, highly demanding, and relentless, while remaining strictly professional, polite, and respectful.",
        probing_intensity="Continuous pressure-testing. Introduce competing constraints, sudden architectural changes, and harsh edge cases.",
        hint_policy="Zero hints. Force hard prioritization under conflicting constraints (e.g. consistency vs availability during split-brain).",
        depth_level="Extreme production stress: high-concurrency race conditions, zero-downtime recovery, compliance vs latency.",
        expected_evidence_bar="Exemplary composure and mastery required. Candidate must structure reasoning under pressure.",
    ),
}


class InterviewPlannerService:
    """Orchestrates structured interview planning combining candidate context, job rubric, interviewer, and difficulty."""

    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        if self.api_key:
            self.client = genai.Client(api_key=self.api_key)
        else:
            self.client = None

    def get_difficulty_config(self, difficulty: str) -> DifficultyConfiguration:
        diff_key = difficulty.lower().strip()
        if diff_key in ("stress", "expert", "expert/stress"):
            diff_key = DifficultyMode.EXPERT_STRESS
        return DIFFICULTY_CONFIGURATIONS.get(diff_key, DIFFICULTY_CONFIGURATIONS[DifficultyMode.REALISTIC])

    async def generate_plan(
        self,
        candidate_data: dict[str, Any],
        job_data: dict[str, Any],
        interviewer_data: dict[str, Any],
        difficulty: str = DifficultyMode.REALISTIC,
    ) -> InterviewSessionPlan:
        """Synthesizes a structured, evidence-testable session plan tailored to candidate and job."""
        diff_config = self.get_difficulty_config(difficulty)

        if self.client:
            try:
                return await self._plan_with_gemini(
                    candidate_data=candidate_data,
                    job_data=job_data,
                    interviewer_data=interviewer_data,
                    diff_config=diff_config,
                )
            except Exception as exc:
                logger.warning("Gemini session planning failed: %s. Using deterministic plan generator.", exc)

        return self._deterministic_fallback_plan(
            candidate_data=candidate_data,
            job_data=job_data,
            interviewer_data=interviewer_data,
            diff_config=diff_config,
        )

    async def _plan_with_gemini(
        self,
        candidate_data: dict[str, Any],
        job_data: dict[str, Any],
        interviewer_data: dict[str, Any],
        diff_config: DifficultyConfiguration,
    ) -> InterviewSessionPlan:
        candidate_name = candidate_data.get("full_name", "Candidate")
        candidate_headline = candidate_data.get("headline", "")
        skills = ", ".join(candidate_data.get("skills") or [])
        projects = candidate_data.get("projects") or []
        experience = candidate_data.get("work_experience") or []

        projects_summary = "\n".join(
            f"- {p.get('name')}: {p.get('description', '')} (Tech: {', '.join(p.get('technologies') or [])})"
            for p in projects[:3]
        ) or "None listed"

        experience_summary = "\n".join(
            f"- {w.get('role')} at {w.get('company')}: {w.get('description', '')}"
            for w in experience[:3]
        ) or "None listed"

        job_title = job_data.get("title", "Software Engineer")
        seniority = job_data.get("seniority", "Senior")
        rubric_competencies = job_data.get("competencies") or []
        competencies_summary = "\n".join(
            f"- {c.get('name')}: {c.get('description', '')} | Observable criteria: {', '.join(c.get('criteria') or [])}"
            for c in rubric_competencies
        ) or "Standard technical competencies"

        interviewer_name = interviewer_data.get("name", "Interviewer")
        interviewer_title = interviewer_data.get("title", "Technical Interviewer")
        interviewer_style = interviewer_data.get("questioning_style", "conversational")

        prompt = f"""You are the Master Interview Architect for FitCheck.
Core principle: "Don't simulate an interview. Simulate THEIR interview."

You must create a comprehensive, tailored InterviewSessionPlan.

CANDIDATE CONTEXT:
Name: {candidate_name}
Headline: {candidate_headline}
Skills: {skills}
Key Projects:
{projects_summary}
Recent Experience:
{experience_summary}

JOB CONTEXT:
Title: {job_title} ({seniority})
Description: {job_data.get('description', '')[:1000]}
Competency Rubric:
{competencies_summary}

INTERVIEWER PERSONA:
Name: {interviewer_name} ({interviewer_title})
Questioning Style: {interviewer_style}

DIFFICULTY LEVEL: {diff_config.difficulty.upper()}
Tone: {diff_config.tone}
Probing Intensity: {diff_config.probing_intensity}
Hint Policy: {diff_config.hint_policy}
Depth Level: {diff_config.depth_level}

RULES:
1. Ground the opening question in the candidate's actual projects or work history, and have the interviewer introduce themselves by name (e.g. "Hi {candidate_name}, I'm {interviewer_name}...").
2. Every competency plan must target either 'experience_deep_dive' or 'technical_assessment'.
3. Follow-up guidance must strictly align with the {diff_config.difficulty} difficulty mode.
4. Output must strictly adhere to the InterviewSessionPlan schema.
"""
        response = await self.client.aio.models.generate_content(
            model="gemini-3.5-flash-lite",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=InterviewSessionPlan,
                temperature=0.2,
            ),
        )

        plan = InterviewSessionPlan.model_validate_json(response.text)
        plan.difficulty = diff_config.difficulty
        plan.difficulty_config = diff_config
        return plan

    def _deterministic_fallback_plan(
        self,
        candidate_data: dict[str, Any],
        job_data: dict[str, Any],
        interviewer_data: dict[str, Any],
        diff_config: DifficultyConfiguration,
    ) -> InterviewSessionPlan:
        """Deterministic plan guaranteed to generate grounded questions matching candidate context and rubric."""
        candidate_name = candidate_data.get("full_name", "Candidate")
        job_title = job_data.get("title", "Software Engineer")
        seniority = job_data.get("seniority", "senior")
        interviewer_name = interviewer_data.get("name", "Interviewer")

        projects = candidate_data.get("projects") or []
        experience = candidate_data.get("work_experience") or []
        first_project = projects[0].get("name") if projects else None
        first_company = experience[0].get("company") if experience else None

        # Build grounded opening question
        if first_project:
            opening_question = (
                f"Hi {candidate_name}, I'm {interviewer_name}. I noticed your work on '{first_project}'. "
                f"To kick things off, could you walk me through the high-level architecture and your primary technical contributions to it?"
            )
        elif first_company:
            opening_question = (
                f"Hi {candidate_name}, welcome! I'm {interviewer_name}. To get started, I'd love to hear about "
                f"your engineering work at {first_company} and the most complex technical challenge you tackled there."
            )
        else:
            opening_question = (
                f"Hello {candidate_name}, welcome to the interview for the {job_title} role. "
                f"I'm {interviewer_name}. Let's start with a brief overview of your technical background and what systems you've enjoyed building most."
            )

        # Build competency plans from job competencies
        rubric_competencies = job_data.get("competencies") or [
            {
                "name": "System Architecture & Scalability",
                "description": f"Core architecture required for {job_title}",
                "criteria": ["Explains component boundaries", "Analyzes latency vs consistency"],
                "weight": 1.0,
            },
            {
                "name": "Code Quality & Operational Reliability",
                "description": "Failure mitigation and testing",
                "criteria": ["Considers monitoring and metrics", "Handles error states"],
                "weight": 1.0,
            },
        ]

        competency_plans = []
        for idx, comp in enumerate(rubric_competencies):
            c_name = comp.get("name", f"Competency {idx+1}")
            c_desc = comp.get("description", "")
            c_criteria = comp.get("criteria") or ["Demonstrates structured problem solving"]
            c_weight = float(comp.get("weight", 1.0))
            stage = InterviewStage.EXPERIENCE_DEEP_DIVE if idx == 0 else InterviewStage.TECHNICAL_ASSESSMENT

            # Difficulty-tailored planned questions and follow-ups
            if diff_config.difficulty == DifficultyMode.LENIENT:
                planned_q = (
                    f"Let's explore {c_name}. When building your systems, how do you typically approach this, "
                    f"and what libraries or patterns have you found helpful?"
                )
                follow_up = (
                    "Offer supportive guidance if the candidate hesitates. "
                    "Ask: 'Would you prefer to discuss caching, partitioning, or error handling first?'"
                )
            elif diff_config.difficulty == DifficultyMode.CHALLENGING:
                planned_q = (
                    f"Regarding {c_name} in the context of {job_title}: walk me through how your architecture holds up "
                    f"under unexpected 10x spikes or downstream service outages. What are the key points of failure?"
                )
                follow_up = (
                    "Challenge initial assumptions immediately. Ask: 'What if network latency between clusters spikes to 200ms? "
                    "How does your design prevent cascading failures?'"
                )
            elif diff_config.difficulty == DifficultyMode.EXPERT_STRESS:
                planned_q = (
                    f"Let's pressure-test {c_name}. You have a strict 50ms p99 SLA, zero data loss guarantees, and the secondary replica network partitions. "
                    f"Walk me through your consensus, write path, and degradation strategy."
                )
                follow_up = (
                    "Zero hints. Introduce conflicting constraints (e.g. storage budget cut by 40% or sudden multi-region compliance laws). "
                    "Observe composure and trade-off precision."
                )
            else:  # REALISTIC
                planned_q = (
                    f"Let's discuss {c_name}. In your experience, how have you designed for this in production, "
                    f"and what trade-offs did you make between simplicity and performance?"
                )
                follow_up = (
                    "Probe 1-2 layers deeper on the candidate's chosen technology. "
                    "Ask: 'Why did you pick this approach over alternatives? What would you do differently today?'"
                )

            competency_plans.append(
                CompetencyPlanItem(
                    name=c_name,
                    description=c_desc,
                    target_stage=stage,
                    planned_question=planned_q,
                    follow_up_guidance=follow_up,
                    observable_criteria=c_criteria,
                    weight=c_weight,
                )
            )

        return InterviewSessionPlan(
            objectives=[
                f"Evaluate candidate against {job_title} ({seniority}) role competencies.",
                f"Gather evidence on {len(competency_plans)} core rubric competencies.",
                f"Calibrate technical rigor to {diff_config.difficulty} difficulty standard.",
            ],
            difficulty=diff_config.difficulty,
            difficulty_config=diff_config,
            competency_plans=competency_plans,
            opening_question=opening_question,
            strategy=PlanStrategy(
                target_duration_minutes=30,
                stages=[
                    InterviewStage.INTRODUCTION,
                    InterviewStage.EXPERIENCE_DEEP_DIVE,
                    InterviewStage.TECHNICAL_ASSESSMENT,
                    InterviewStage.CANDIDATE_QUESTIONS,
                ],
                early_exit_min_evidence_turns=4,
            ),
            follow_up_rules=[
                "Reference specific technologies from the candidate's response.",
                "Probe into concrete trade-offs, metrics, and past mistakes.",
                "Never invent candidate experience not present in transcript or profile.",
                f"Maintain the {diff_config.difficulty} tone ({diff_config.tone}).",
            ],
            completion_criteria=[
                "Evidence has been gathered for all primary competencies, OR",
                "Candidate has explicitly indicated they have no further answers, OR",
                "Time limit has been reached after candidate Q&A.",
            ],
        )
