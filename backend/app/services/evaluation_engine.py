from __future__ import annotations

import logging
import os
import re
from typing import Any
import uuid

from google import genai
from google.genai import types

from app.domain.schemas import (
    CompetencyEvaluationScore,
    DifficultyMode,
    EvaluationResponse,
    TranscriptEvidenceCitation,
)

logger = logging.getLogger(__name__)


class EvaluationEngineService:
    """Evaluates interview transcripts against competency rubrics with strict citation verification."""

    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        if self.api_key:
            self.client = genai.Client(api_key=self.api_key)
        else:
            self.client = None

    async def evaluate_interview(
        self,
        session_id: str,
        user_id: str,
        transcript: list[dict[str, Any]],
        rubric_competencies: list[dict[str, Any]],
        difficulty: str = DifficultyMode.REALISTIC,
    ) -> EvaluationResponse:
        """Evaluates interview performance, verifies transcript quotes, and outputs an evidence-backed report."""
        clean_turns = self._normalize_transcript(transcript)

        if self.client and len(clean_turns) >= 2:
            try:
                report = await self._evaluate_with_gemini(
                    session_id=session_id,
                    user_id=user_id,
                    clean_turns=clean_turns,
                    rubric_competencies=rubric_competencies,
                    difficulty=difficulty,
                )
                self._verify_evidence_citations(report.competency_scores, clean_turns)
                return report
            except Exception as exc:
                logger.warning("Gemini evaluation failed: %s. Using deterministic evaluation engine.", exc)

        return self._deterministic_fallback_evaluation(
            session_id=session_id,
            user_id=user_id,
            clean_turns=clean_turns,
            rubric_competencies=rubric_competencies,
            difficulty=difficulty,
        )

    def _normalize_transcript(self, transcript: list[dict[str, Any]]) -> list[dict[str, Any]]:
        """Ensures consistent turn numbering and role naming across transcript turns."""
        normalized = []
        for turn in transcript:
            role = str(turn.get("role") or turn.get("speaker") or "").lower()
            speaker = "candidate" if role in ("candidate", "user") else "interviewer"
            text = str(turn.get("text", "")).strip()
            # Discard any raw Agora protocol framing, base64 data, or internal states
            if not text:
                continue
            if any(marker in text for marker in ("|1|1|", "|1|2|", "|2|2|", "eyJvYm", "message.state", "agent.state")):
                continue
            normalized.append({
                "turn_index": len(normalized),
                "speaker": speaker,
                "text": text,
            })
        return normalized

    def _verify_evidence_citations(
        self,
        competency_scores: list[dict[str, Any]],
        clean_turns: list[dict[str, Any]],
    ) -> None:
        """Verifies that all quoted evidence in competency scores matches actual candidate turns."""
        candidate_turns_by_index = {
            t["turn_index"]: t["text"]
            for t in clean_turns
            if t["speaker"] == "candidate"
        }
        all_candidate_text = " ".join(candidate_turns_by_index.values()).lower()

        for comp in competency_scores:
            citations = comp.get("evidence_citations") or []
            for cit in citations:
                quote = cit.get("quote", "").strip()
                turn_idx = cit.get("turn_index")

                # Validate quote existence
                verified = False
                if turn_idx in candidate_turns_by_index:
                    if quote.lower() in candidate_turns_by_index[turn_idx].lower():
                        verified = True
                if not verified and quote.lower() in all_candidate_text:
                    verified = True

                cit["verified"] = verified
                if not verified:
                    cit["quote"] = f"[Unverified citation]: {quote[:80]}"

    async def _evaluate_with_gemini(
        self,
        session_id: str,
        user_id: str,
        clean_turns: list[dict[str, Any]],
        rubric_competencies: list[dict[str, Any]],
        difficulty: str,
    ) -> EvaluationResponse:
        transcript_formatted = "\n".join(
            f"[Turn {t['turn_index']} - {t['speaker'].upper()}]: {t['text']}"
            for t in clean_turns
        )

        rubric_formatted = "\n".join(
            f"Competency: {c.get('name')}\n"
            f"Description: {c.get('description', '')}\n"
            f"Observable Criteria: {', '.join(c.get('criteria') or [])}\n"
            f"Weight: {c.get('weight', 1.0)}"
            for c in rubric_competencies
        )

        prompt = f"""You are the Lead Technical Evaluator for FitCheck.
Assess this interview transcript against the job rubric with rigorous, evidence-based scoring.

DIFFICULTY LEVEL: {difficulty.upper()}

COMPETENCY RUBRIC:
{rubric_formatted}

INTERVIEW TRANSCRIPT:
{transcript_formatted}

EVALUATION RULES:
1. Ground every competency score in observable criteria and transcript evidence.
2. For each evidence citation, quote the EXACT sentence spoken by the candidate and specify its turn_index.
3. DO NOT equate lack of evidence with lack of ability. If a topic was never covered, mark status='insufficient_evidence', and record it under 'insufficient_evidence', not as a demonstrated gap.
4. Distinguish between 'demonstrated_gaps' (topics the candidate attempted but showed flawed reasoning/anti-patterns) and 'insufficient_evidence' (unexplored areas).
5. Provide actionable, targeted preparation recommendations.
"""
        response = await self.client.aio.models.generate_content(
            model="gemini-3.5-flash-lite",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=EvaluationResponse,
                temperature=0.1,
            ),
        )

        report = EvaluationResponse.model_validate_json(response.text)
        report.session_id = session_id
        report.user_id = user_id
        return report

    def _deterministic_fallback_evaluation(
        self,
        session_id: str,
        user_id: str,
        clean_turns: list[dict[str, Any]],
        rubric_competencies: list[dict[str, Any]],
        difficulty: str,
    ) -> EvaluationResponse:
        """Deterministic, evidence-linked evaluation when AI service is unavailable."""
        candidate_turns = [t for t in clean_turns if t["speaker"] == "candidate"]

        competency_scores = []
        observed_strengths = []
        demonstrated_gaps = []
        insufficient_evidence = []
        total_weighted_score = 0.0
        total_weight = 0.0

        for comp in rubric_competencies:
            name = comp.get("name", "Technical Competency")
            desc = comp.get("description", "")
            criteria = comp.get("criteria") or ["Demonstrates structured thinking"]
            weight = float(comp.get("weight", 1.0))

            matching_citations = []
            criteria_met = []
            criteria_missed = []

            # Check criteria against candidate turns
            # Also extract keywords from description to connect general discussion
            combined_match_phrases = list(criteria)
            if desc:
                combined_match_phrases.append(desc)

            for turn in candidate_turns:
                turn_text = turn["text"]
                turn_lower = turn_text.lower()
                for target_phrase in combined_match_phrases:
                    words = [w for w in re.findall(r"\b[A-Za-z]{4,}\b", target_phrase.lower()) if w not in ("with", "that", "from", "have", "used", "using")]
                    if any(w in turn_lower for w in words[:6]):
                        # Map to matching criteria
                        matched_crit = next((c for c in criteria if any(w in c.lower() for w in words[:6])), criteria[0])
                        if matched_crit not in criteria_met:
                            criteria_met.append(matched_crit)
                        quote_snippet = turn_text[:140].strip()
                        if not any(mc["quote"] == quote_snippet for mc in matching_citations):
                            matching_citations.append({
                                "quote": quote_snippet,
                                "turn_index": turn["turn_index"],
                                "speaker": "candidate",
                                "relevance": f"Addresses criterion: '{matched_crit}'",
                                "verified": True,
                            })

            criteria_missed = [c for c in criteria if c not in criteria_met]

            if not matching_citations:
                status = "insufficient_evidence"
                score = 0.0 if not candidate_turns else 1.0
                explanation = (
                    "No candidate responses were recorded during the session."
                    if not candidate_turns
                    else f"The candidate was not asked about or did not discuss '{name}' during this session."
                )
                insufficient_evidence.append(f"Insufficient signal on '{name}' due to limited discussion time.")
            else:
                status = "evaluated"
                ratio = len(criteria_met) / max(len(criteria), 1)
                # Calibrate score to difficulty
                if difficulty == DifficultyMode.LENIENT:
                    score = round(3.5 + (ratio * 1.5), 1)
                elif difficulty == DifficultyMode.CHALLENGING:
                    score = round(2.5 + (ratio * 2.0), 1)
                elif difficulty == DifficultyMode.EXPERT_STRESS:
                    score = round(2.0 + (ratio * 2.5), 1)
                else:  # REALISTIC
                    score = round(3.0 + (ratio * 2.0), 1)

                explanation = (
                    f"Candidate addressed {len(criteria_met)} of {len(criteria)} observable criteria with direct evidence."
                )
                if ratio >= 0.5:
                    observed_strengths.append(f"Clear articulation of {name} ({criteria_met[0] if criteria_met else ''}).")
                else:
                    demonstrated_gaps.append(f"Limited depth shown on {name}; omitted {criteria_missed[0] if criteria_missed else 'key trade-offs'}.")

            total_weighted_score += score * weight
            total_weight += weight

            competency_scores.append({
                "competency_name": name,
                "score": score,
                "weight": weight,
                "status": status,
                "criteria_met": criteria_met,
                "criteria_missed": criteria_missed,
                "evidence_citations": matching_citations[:3],
                "explanation": explanation,
            })

        if not candidate_turns:
            overall_score = 0.0
            recommendation = "Insufficient Evidence"
            summary_verdict = (
                "Session terminated with no candidate verbal responses recorded. "
                "Unable to evaluate technical competencies or provide hiring recommendation without candidate speech evidence."
            )
            prep_recs = [
                "Ensure your microphone is connected and browser permissions are granted before starting the interview.",
                "Verify live transcript updates on screen as you speak to confirm voice capture.",
            ]
        else:
            evaluated_comps = [c for c in competency_scores if c["status"] == "evaluated"]
            if evaluated_comps:
                eval_weighted_score = sum(c["score"] * c["weight"] for c in evaluated_comps)
                eval_total_weight = sum(c["weight"] for c in evaluated_comps)
                overall_score = round(eval_weighted_score / max(eval_total_weight, 1.0), 1)
            else:
                overall_score = 1.0

            if overall_score >= 4.2:
                recommendation = "Strong Hire"
            elif overall_score >= 3.6:
                recommendation = "Hire"
            elif overall_score >= 3.0:
                recommendation = "Leaning Hire"
            elif overall_score >= 2.4:
                recommendation = "Leaning Reject"
            elif overall_score > 0.0:
                recommendation = "Reject"
            else:
                recommendation = "Insufficient Signal"

            if len(insufficient_evidence) >= len(rubric_competencies) // 2:
                recommendation = "Insufficient Signal"

            summary_verdict = (
                f"Candidate completed {difficulty} interview session with overall score of {overall_score}/5.0. "
                f"Evaluation is based on verified transcript quotations mapped directly to role competencies."
            )
            prep_recs = [
                f"Review observable criteria for '{gap.split(';')[0]}'"
                for gap in demonstrated_gaps[:2]
            ] or ["Practice articulating system trade-offs with explicit quantitative metrics under time constraints."]

        return EvaluationResponse(
            id=f"eval-{uuid.uuid4().hex[:10]}",
            session_id=session_id,
            user_id=user_id,
            overall_score=overall_score,
            overall_recommendation=recommendation,
            summary_verdict=(
                f"Candidate completed {difficulty} interview session with overall score of {overall_score}/5.0. "
                f"Evaluation is based on verified transcript quotations mapped directly to role competencies."
            ),
            competency_scores=competency_scores,
            observed_strengths=observed_strengths or ["Participated constructively in technical dialogue."],
            technical_gaps=demonstrated_gaps,
            insufficient_evidence=insufficient_evidence,
            preparation_recommendations=prep_recs,
            human_review={
                "requires_human_adjudication": recommendation in ("Insufficient Signal", "Leaning Hire", "Leaning Reject"),
                "adjudication_notes": "FitCheck evaluations provide structured evidence for human decision-makers, not automated hiring rejections.",
            },
            created_at=None,
        )

