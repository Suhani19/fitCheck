from __future__ import annotations

import logging
import os
from typing import Any

from google import genai
from google.genai import types

from app.domain.schemas import (
    CompetencyRubricItem,
    RubricGenerationRequest,
    RubricGenerationResponse,
)

logger = logging.getLogger(__name__)


class RubricGeneratorService:
    """Service for generating structured, evidence-testable competency rubrics for jobs."""

    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        if self.api_key:
            self.client = genai.Client(api_key=self.api_key)
        else:
            self.client = None

    async def generate_rubric(
        self,
        request: RubricGenerationRequest,
    ) -> RubricGenerationResponse:
        """Generates 3 to 5 structured competencies with observable evaluation criteria."""
        if self.client:
            try:
                return await self._generate_with_gemini(request)
            except Exception as e:
                logger.warning(
                    "Gemini rubric generation failed: %s. Falling back to deterministic rubric generator.",
                    str(e),
                )

        return self._deterministic_fallback_rubric(request)

    async def _generate_with_gemini(
        self,
        request: RubricGenerationRequest,
    ) -> RubricGenerationResponse:
        skills_str = ", ".join(request.required_skills) if request.required_skills else "General technical skills"
        prompt = f"""You are an expert technical recruiter and interview rubric architect.
Design a rigorous, structured competency rubric for an interview evaluation.

Job Title: {request.title}
Seniority Level: {request.seniority}
Required Skills: {skills_str}

Job Description:
\"\"\"
{request.description[:4000]}
\"\"\"

Requirements for generated competencies:
1. Provide 3 to 5 distinct competencies that are essential to evaluating success in this role.
2. For each competency, provide:
   - name: Clear competency name (e.g., 'System Architecture & Scalability', 'API Design & Reliability', 'Problem Solving & Algorithmic Thinking', 'Technical Communication & Collaboration').
   - description: Why this competency is critical for this specific role and seniority level.
   - criteria: 3 to 5 specific, observable behavioral indicators or evaluation criteria that an interviewer can observe in real-time conversation.
   - weight: Float weight between 0.5 and 2.0 (default 1.0).
3. Do NOT include vague criteria like 'knows how to code'. Criteria must be observable in a verbal interview (e.g., 'Articulates latency vs consistency tradeoffs', 'Discusses failure recovery mechanisms').
"""
        response = await self.client.aio.models.generate_content(
            model="gemini-3.5-flash-lite",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=RubricGenerationResponse,
                temperature=0.2,
            ),
        )

        raw_json = response.text
        # Strict Pydantic validation
        parsed = RubricGenerationResponse.model_validate_json(raw_json)

        # Validate that competencies and criteria are non-empty
        if not parsed.competencies or len(parsed.competencies) < 2:
            raise ValueError("Generated rubric returned insufficient competencies.")

        for comp in parsed.competencies:
            if not comp.name.strip() or not comp.description.strip():
                raise ValueError("Generated competency has missing name or description.")
            if not comp.criteria or len(comp.criteria) == 0:
                raise ValueError(f"Competency '{comp.name}' has no observable criteria.")

        return parsed

    def _deterministic_fallback_rubric(
        self,
        request: RubricGenerationRequest,
    ) -> RubricGenerationResponse:
        """Standard high-quality fallback rubric when AI generation is unavailable."""
        title_lower = request.title.lower()
        is_senior = request.seniority.lower() in ("senior", "staff", "principal", "lead")

        competencies = [
            CompetencyRubricItem(
                name="Domain Knowledge & Core Fundamentals",
                description=f"Mastery of core concepts and technologies required for {request.title}.",
                criteria=[
                    "Explains underlying mechanisms and protocols clearly rather than reciting buzzwords.",
                    "Demonstrates practical hands-on familiarity with relevant tools and libraries.",
                    "Identifies common anti-patterns and performance bottlenecks in their domain.",
                ],
                weight=1.0,
            ),
            CompetencyRubricItem(
                name="Architecture & Systems Design",
                description="Ability to design robust, maintainable, and scalable systems within constraints.",
                criteria=[
                    "Breaks complex requirements down into clean, decoupled components.",
                    "Explicitly identifies tradeoffs (e.g. latency vs consistency, complexity vs speed).",
                    "Plans for failure modes, monitoring, and boundary validation.",
                ] if is_senior else [
                    "Understands component interaction and basic data flow.",
                    "Follows standard architectural patterns and idioms.",
                    "Recognizes basic failure points and edge cases.",
                ],
                weight=1.2 if is_senior else 1.0,
            ),
            CompetencyRubricItem(
                name="Problem Solving & Analytical Rigor",
                description="Structured approach to troubleshooting, ambiguity, and technical challenges.",
                criteria=[
                    "Asks clarifying questions before jumping into implementation or architecture.",
                    "Structures reasoning logically and tests assumptions methodically.",
                    "Pivots gracefully when presented with new constraints or counter-examples.",
                ],
                weight=1.0,
            ),
            CompetencyRubricItem(
                name="Technical Communication & Professional Maturity",
                description="Clarity of thought, collaborative presence, and ownership mindset.",
                criteria=[
                    "Explains technical concepts with precision and appropriate depth for the listener.",
                    "Listens actively and incorporates interviewer feedback and hints.",
                    "Demonstrates self-awareness regarding knowledge boundaries and past engineering mistakes.",
                ],
                weight=0.8,
            ),
        ]

        return RubricGenerationResponse(competencies=competencies)
