from __future__ import annotations

from datetime import datetime, timezone
import logging
import os
from typing import Any

from google import genai
from google.genai import types
from pydantic import BaseModel, Field

from app.domain.schemas import (
    DEFAULT_SIMULATION_DISCLAIMER,
    InterviewerCreateRequest,
    InterviewerFactProvenance,
    InterviewerPersonalizeRequest,
    InterviewerProvenance,
)

logger = logging.getLogger(__name__)


class GeminiInterviewerExtraction(BaseModel):
    bio_summary: str = Field(description="Objective factual professional summary")
    verified_facts: list[str] = Field(description="Strictly factual statements extracted directly from provided text")
    inferred_focus_areas: list[str] = Field(description="Likely technical and architectural topics based on domain")
    recommended_questioning_style: str = Field(default="conversational")


class InterviewerPersonalizerService:
    """Service for synthesizing provenance-aware interviewer personas with strict boundary separation."""

    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        if self.api_key:
            self.client = genai.Client(api_key=self.api_key)
        else:
            self.client = None

    async def personalize_interviewer(
        self,
        request: InterviewerPersonalizeRequest,
    ) -> InterviewerCreateRequest:
        """Constructs an interviewer persona separating verified career facts from inferred style."""
        now_iso = datetime.now(timezone.utc).isoformat()
        source_url = request.public_url

        if self.client and (request.public_profile_text or request.user_notes):
            try:
                return await self._personalize_with_gemini(request, now_iso)
            except Exception as e:
                logger.warning(
                    "Gemini interviewer personalization failed: %s. Using deterministic persona builder.",
                    str(e),
                )

        return self._deterministic_fallback_personalization(request, now_iso)

    async def _personalize_with_gemini(
        self,
        request: InterviewerPersonalizeRequest,
        retrieval_date: str,
    ) -> InterviewerCreateRequest:
        context_text = f"""
Name: {request.name}
Title: {request.title}
Company / Domain: {request.company_context or 'General Tech'}
Public Profile Context:
{request.public_profile_text or 'None provided'}

User Notes / Custom Requirements:
{request.user_notes or 'None provided'}
"""
        prompt = f"""You are an objective provenance analyzer for FitCheck interview simulations.
Extract factual professional context to configure an interview persona.

CRITICAL RULES:
1. ONLY extract verified facts that are directly stated in the input text (e.g. past companies, technologies used, leadership roles).
2. DO NOT invent opinions, personal beliefs, trick questions, or unsupported claims about the person.
3. Clearly distinguish between verified facts and the inferred conversational focus.
4. Ensure the persona is presented as an objective simulation for interview practice.

Input Context:
\"\"\"
{context_text[:5000]}
\"\"\"
"""
        response = await self.client.aio.models.generate_content(
            model="gemini-3.5-flash-lite",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=GeminiInterviewerExtraction,
                temperature=0.1,
            ),
        )

        extracted = GeminiInterviewerExtraction.model_validate_json(response.text)

        verified_facts = [
            InterviewerFactProvenance(
                fact=fact,
                source_url=request.public_url,
                source_type="public_profile" if request.public_profile_text else "user_provided",
                retrieval_date=retrieval_date,
                verified=True,
            )
            for fact in extracted.verified_facts
        ]

        if not verified_facts:
            verified_facts.append(
                InterviewerFactProvenance(
                    fact=f"{request.name} serves as {request.title}.",
                    source_url=request.public_url,
                    source_type="user_provided",
                    retrieval_date=retrieval_date,
                    verified=True,
                )
            )

        provenance = InterviewerProvenance(
            verified_facts=verified_facts,
            inferred_style={
                "focus_areas": extracted.inferred_focus_areas,
                "inferred_posture": f"Simulates professional questioning typical of a {request.title}",
                "simulated": True,
            },
            disclaimer=DEFAULT_SIMULATION_DISCLAIMER,
        )

        style = request.questioning_style or extracted.recommended_questioning_style

        return InterviewerCreateRequest(
            name=request.name,
            title=request.title,
            bio=extracted.bio_summary,
            company_context=request.company_context,
            questioning_style=style,
            voice_id=request.voice_id or "Puck",
            provenance=provenance.model_dump(),
        )

    def _deterministic_fallback_personalization(
        self,
        request: InterviewerPersonalizeRequest,
        retrieval_date: str,
    ) -> InterviewerCreateRequest:
        """Deterministic persona builder with complete provenance metadata."""
        verified_facts = [
            InterviewerFactProvenance(
                fact=f"{request.name} is described as {request.title}.",
                source_url=request.public_url,
                source_type="user_provided",
                retrieval_date=retrieval_date,
                verified=True,
            )
        ]
        if request.company_context:
            verified_facts.append(
                InterviewerFactProvenance(
                    fact=f"Professional organization or context: {request.company_context}.",
                    source_url=request.public_url,
                    source_type="user_provided",
                    retrieval_date=retrieval_date,
                    verified=True,
                )
            )
        if request.user_notes:
            verified_facts.append(
                InterviewerFactProvenance(
                    fact=f"User-specified context: {request.user_notes[:200]}.",
                    source_url=None,
                    source_type="user_provided",
                    retrieval_date=retrieval_date,
                    verified=True,
                )
            )

        provenance = InterviewerProvenance(
            verified_facts=verified_facts,
            inferred_style={
                "focus_areas": ["Domain architecture", "Practical problem solving", "Technical communication"],
                "inferred_posture": f"Standard {request.questioning_style} style simulation for {request.title}",
                "simulated": True,
            },
            disclaimer=DEFAULT_SIMULATION_DISCLAIMER,
        )

        bio = f"{request.name} is a {request.title}"
        if request.company_context:
            bio += f" with context in {request.company_context}."
        else:
            bio += "."

        return InterviewerCreateRequest(
            name=request.name,
            title=request.title,
            bio=bio,
            company_context=request.company_context,
            questioning_style=request.questioning_style or "conversational",
            voice_id=request.voice_id or "Puck",
            provenance=provenance.model_dump(),
        )
