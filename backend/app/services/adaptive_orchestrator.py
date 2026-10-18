import logging
import os
import re
from typing import Any

from google import genai
from google.genai import types

from app.domain.schemas import (
    AdaptiveQuestionResult,
    CompetencyCoverageStatus,
    DifficultyMode,
    InterviewSessionPlan,
    InterviewStage,
    StageTransitionDecision,
)

logger = logging.getLogger(__name__)


class AdaptiveInterviewOrchestrator:
    """Tracks interview stage progression, competency evidence, and generates adaptive follow-up questions."""

    def __init__(self, session_plan: InterviewSessionPlan, api_key: str | None = None) -> None:
        self.session_plan = session_plan
        self.difficulty = session_plan.difficulty.lower()
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        if self.api_key:
            try:
                self.client = genai.Client(api_key=self.api_key)
            except Exception as e:
                logger.warning("Could not initialize Gemini client for AdaptiveInterviewOrchestrator: %s", e)
                self.client = None
        else:
            self.client = None

    def track_competency_coverage(
        self,
        transcript: list[dict[str, Any]],
    ) -> dict[str, CompetencyCoverageStatus]:
        """Analyzes transcript turns to assess coverage for each competency in the session plan."""
        coverage: dict[str, CompetencyCoverageStatus] = {}

        candidate_turns = [
            t.get("text", "")
            for t in transcript
            if t.get("role", "").lower() in ("candidate", "user") and len(t.get("text", "").strip()) > 10
        ]
        all_candidate_text = " ".join(candidate_turns).lower()

        for comp in self.session_plan.competency_plans:
            comp_name = comp.name
            evidence_count = 0
            observations = []

            # Check criteria keyword hits in candidate statements
            keywords = [
                kw.strip().lower()
                for criterion in comp.observable_criteria
                for kw in re.findall(r"\b[A-Za-z]{4,}\b", criterion)
                if kw.lower() not in ("with", "that", "from", "have", "this", "their", "into", "than")
            ]
            unique_keywords = set(keywords)

            for turn_idx, turn_text in enumerate(candidate_turns):
                turn_lower = turn_text.lower()
                matched = [k for k in unique_keywords if k in turn_lower]
                if len(matched) >= 2 or (len(turn_text) > 80 and any(w in turn_lower for w in comp_name.lower().split())):
                    evidence_count += 1
                    snippet = turn_text[:120].strip() + ("..." if len(turn_text) > 120 else "")
                    observations.append(f"Turn {turn_idx+1}: {snippet}")

            if evidence_count == 0:
                status = "unexplored"
            elif evidence_count == 1:
                status = "in_progress"
            else:
                status = "covered"

            coverage[comp_name] = CompetencyCoverageStatus(
                competency_name=comp_name,
                status=status,
                evidence_count=evidence_count,
                key_observations=observations,
            )

        return coverage

    def evaluate_stage_transition(
        self,
        transcript: list[dict[str, Any]],
        current_stage: str = InterviewStage.INTRODUCTION,
    ) -> StageTransitionDecision:
        """Determines whether to advance the interview stage based on conversation turns and evidence."""
        coverage = self.track_competency_coverage(transcript)
        candidate_turns = [
            t for t in transcript if t.get("role", "").lower() in ("candidate", "user")
        ]
        num_candidate_turns = len(candidate_turns)

        unexplored = [
            name for name, cov in coverage.items() if cov.status == "unexplored"
        ]
        all_covered = all(cov.status == "covered" for cov in coverage.values()) if coverage else False

        # Introduction -> Experience Deep Dive (after 1 or 2 candidate greeting/intro turns)
        if current_stage == InterviewStage.INTRODUCTION:
            if num_candidate_turns >= 1:
                return StageTransitionDecision(
                    current_stage=current_stage,
                    next_stage=InterviewStage.EXPERIENCE_DEEP_DIVE,
                    should_transition=True,
                    reason="Introduction complete; moving to experience deep dive.",
                    remaining_unexplored_competencies=unexplored,
                )
            return StageTransitionDecision(
                current_stage=current_stage,
                next_stage=current_stage,
                should_transition=False,
                reason="Candidate has not yet completed introduction.",
                remaining_unexplored_competencies=unexplored,
            )

        # Experience Deep Dive -> Technical Assessment
        if current_stage == InterviewStage.EXPERIENCE_DEEP_DIVE:
            # Check if experience competencies have at least some signal, or 3+ turns
            if num_candidate_turns >= 3:
                return StageTransitionDecision(
                    current_stage=current_stage,
                    next_stage=InterviewStage.TECHNICAL_ASSESSMENT,
                    should_transition=True,
                    reason="Past experience sufficiently explored; progressing to technical assessment.",
                    remaining_unexplored_competencies=unexplored,
                )
            return StageTransitionDecision(
                current_stage=current_stage,
                next_stage=current_stage,
                should_transition=False,
                reason="Exploring past project details in depth.",
                remaining_unexplored_competencies=unexplored,
            )

        # Technical Assessment -> Candidate Questions
        if current_stage == InterviewStage.TECHNICAL_ASSESSMENT:
            if all_covered or num_candidate_turns >= 7:
                return StageTransitionDecision(
                    current_stage=current_stage,
                    next_stage=InterviewStage.CANDIDATE_QUESTIONS,
                    should_transition=True,
                    reason="Core competencies covered; opening floor for candidate questions.",
                    remaining_unexplored_competencies=unexplored,
                    ready_for_early_completion=all_covered,
                )
            return StageTransitionDecision(
                current_stage=current_stage,
                next_stage=current_stage,
                should_transition=False,
                reason="Technical assessment in progress.",
                remaining_unexplored_competencies=unexplored,
            )

        # Candidate Questions -> Completed
        if current_stage == InterviewStage.CANDIDATE_QUESTIONS:
            last_turn = transcript[-1].get("text", "").lower() if transcript else ""
            if any(p in last_turn for p in ["no questions", "that covers it", "thank you", "thanks for answering", "all set"]):
                return StageTransitionDecision(
                    current_stage=current_stage,
                    next_stage=InterviewStage.COMPLETED,
                    should_transition=True,
                    reason="Candidate questions concluded.",
                    remaining_unexplored_competencies=unexplored,
                    ready_for_early_completion=True,
                )
            if num_candidate_turns >= 9:
                return StageTransitionDecision(
                    current_stage=current_stage,
                    next_stage=InterviewStage.COMPLETED,
                    should_transition=True,
                    reason="Allocated interview time completed.",
                    remaining_unexplored_competencies=unexplored,
                    ready_for_early_completion=True,
                )

        return StageTransitionDecision(
            current_stage=current_stage,
            next_stage=current_stage,
            should_transition=False,
            reason="Continuing in current stage.",
            remaining_unexplored_competencies=unexplored,
        )

    def select_next_question(
        self,
        transcript: list[dict[str, Any]],
        current_stage: str = InterviewStage.INTRODUCTION,
    ) -> AdaptiveQuestionResult:
        """Selects or synthesizes an adaptive question tailored to candidate answers and difficulty mode."""
        # 1. Opening Question
        if not transcript:
            return AdaptiveQuestionResult(
                question=self.session_plan.opening_question,
                stage=InterviewStage.INTRODUCTION,
                targeted_competency=None,
                rationale="Opening interview greeting and kickoff grounded in candidate background.",
                is_follow_up=False,
                difficulty_tone=self.session_plan.difficulty_config.tone,
            )

        # Check existing questions to prevent duplicates
        past_interviewer_questions = [
            t.get("text", "")
            for t in transcript
            if t.get("role", "").lower() in ("assistant", "interviewer")
        ]

        # Extract last candidate answer
        candidate_turns = [
            t for t in transcript if t.get("role", "").lower() in ("candidate", "user")
        ]
        last_candidate_turn = candidate_turns[-1].get("text", "").strip() if candidate_turns else ""

        # 2. Clarification Needed Check
        if len(last_candidate_turn.split()) < 10 and not any(w in last_candidate_turn.lower() for w in ["yes", "no", "ready", "hello"]):
            clarification_q = (
                f"Could you elaborate a bit more on that? Specifically, what was your direct role, "
                f"and how did you measure the outcome?"
            )
            return AdaptiveQuestionResult(
                question=clarification_q,
                stage=current_stage,
                targeted_competency=None,
                rationale="Candidate's prior response was brief; requesting concrete detail.",
                is_follow_up=True,
                clarification_needed=True,
                difficulty_tone=self.session_plan.difficulty_config.tone,
            )

        # 3. Track Competency Coverage
        coverage = self.track_competency_coverage(transcript)
        unexplored_comps = [
            comp for comp in self.session_plan.competency_plans
            if coverage.get(comp.name, CompetencyCoverageStatus(competency_name=comp.name)).status == "unexplored"
        ]

        # In candidate questions stage
        if current_stage == InterviewStage.CANDIDATE_QUESTIONS:
            return AdaptiveQuestionResult(
                question="We have a few minutes left. What questions do you have for me about our engineering challenges or team culture?",
                stage=InterviewStage.CANDIDATE_QUESTIONS,
                targeted_competency=None,
                rationale="Inviting candidate questions before conclusion.",
                is_follow_up=False,
                difficulty_tone=self.session_plan.difficulty_config.tone,
            )

        # In experience deep-dive or technical assessment
        target_comp = None
        for comp in unexplored_comps:
            if comp.target_stage == current_stage:
                target_comp = comp
                break
        if not target_comp and unexplored_comps:
            target_comp = unexplored_comps[0]

        # Check if candidate mentioned key technical concepts in their last turn to make an adaptive follow-up
        tech_matches = re.findall(
            r"\b(Kafka|PostgreSQL|Postgres|Redis|FastAPI|Docker|Kubernetes|AWS|GCP|Azure|Go|Python|Rust|Java|"
            r"gRPC|GraphQL|REST|DynamoDB|Elasticsearch|Cassandra|MongoDB|RabbitMQ|"
            r"sharding|partition|replication|consensus|Raft|Paxos|caching|cache|concurrency|deadlock|mutex|"
            r"latency|throughput|p99|microservices|monolith|circuit breaker|rate limit|load balancer|"
            r"ownership|conflict|incident|postmortem|outage|scale|zero-trust|oauth|encryption)\b",
            last_candidate_turn,
            re.IGNORECASE,
        )

        if tech_matches and len(candidate_turns) >= 1:
            tech = tech_matches[0]
            # Adapt follow-up based on difficulty
            if self.difficulty == DifficultyMode.LENIENT:
                follow_up = (
                    f"You mentioned utilizing {tech}. What aspects of {tech} made it a good fit for your team, "
                    f"and what did you find most straightforward when working with it?"
                )
            elif self.difficulty == DifficultyMode.CHALLENGING:
                follow_up = (
                    f"You highlighted {tech}. What was the biggest scaling bottleneck or failure mode you hit with {tech}, "
                    f"and what specific metrics proved that your fix worked?"
                )
            elif self.difficulty == DifficultyMode.EXPERT_STRESS:
                follow_up = (
                    f"Given your use of {tech}, imagine a scenario where partition leadership flapping occurs during a regional failover. "
                    f"How does your architecture handle write reconciliation without data divergence?"
                )
            else:  # REALISTIC
                follow_up = (
                    f"You mentioned {tech}. What other alternatives did you evaluate before choosing {tech}, "
                    f"and what operational trade-offs did you encounter in production?"
                )

            # Ensure not a duplicate
            if not self._is_duplicate_question(follow_up, past_interviewer_questions):
                return AdaptiveQuestionResult(
                    question=follow_up,
                    stage=current_stage,
                    targeted_competency=target_comp.name if target_comp else None,
                    rationale=f"Grounded follow-up based on candidate's mention of {tech}.",
                    is_follow_up=True,
                    difficulty_tone=self.session_plan.difficulty_config.tone,
                )

        # Contextual extraction for non-keyword answers
        if not tech_matches and len(candidate_turns) >= 1 and len(last_candidate_turn) > 15:
            content_words = [
                w for w in re.findall(r"\b[A-Za-z]{4,}\b", last_candidate_turn)
                if w.lower() not in ("that", "this", "with", "from", "have", "were", "been", "would", "could", "should", "about", "just", "like", "when", "into", "their", "there", "what", "which", "some", "more", "then", "than")
            ]
            if content_words:
                concept = f"'{content_words[0]}'" if len(content_words) == 1 else f"'{content_words[0]}' and '{content_words[1]}'"
                if self.difficulty == DifficultyMode.CHALLENGING:
                    follow_up = f"You discussed {concept}. In a high-traffic production scenario where that layer fails, what specific metric alerts your team, and how is availability preserved?"
                elif self.difficulty == DifficultyMode.EXPERT_STRESS:
                    follow_up = f"Regarding {concept}, suppose network latency spikes across your regions. What trade-offs will you accept to prevent cascading timeouts?"
                else:
                    follow_up = f"You highlighted {concept}. What alternative approaches did you evaluate before settling on this direction, and what was the main operational trade-off?"

                if not self._is_duplicate_question(follow_up, past_interviewer_questions):
                    return AdaptiveQuestionResult(
                        question=follow_up,
                        stage=current_stage,
                        targeted_competency=target_comp.name if target_comp else None,
                        rationale=f"Contextual follow-up grounded in candidate discussion of {concept}.",
                        is_follow_up=True,
                        difficulty_tone=self.session_plan.difficulty_config.tone,
                    )

        # Fallback to next planned competency question
        if target_comp and not self._is_duplicate_question(target_comp.planned_question, past_interviewer_questions):
            return AdaptiveQuestionResult(
                question=target_comp.planned_question,
                stage=current_stage,
                targeted_competency=target_comp.name,
                rationale=f"Advancing to planned evaluation for '{target_comp.name}'.",
                is_follow_up=False,
                difficulty_tone=self.session_plan.difficulty_config.tone,
            )

        # General progression question
        general_q = (
            "Looking across your recent engineering projects, what was a scenario where a production incident "
            "forced you to rethink your system architecture or testing strategy?"
        )
        return AdaptiveQuestionResult(
            question=general_q,
            stage=current_stage,
            targeted_competency=None,
            rationale="Exploring general engineering maturity and incident response.",
            is_follow_up=False,
            difficulty_tone=self.session_plan.difficulty_config.tone,
        )

    async def select_next_question_async(
        self,
        transcript: list[dict[str, Any]],
        current_stage: str = InterviewStage.INTRODUCTION,
        interviewer_persona: dict[str, Any] | None = None,
    ) -> AdaptiveQuestionResult:
        """Asynchronously synthesizes an adaptive follow-up using Gemini LLM if configured, falling back to deterministic generation."""
        candidate_turns = [
            t for t in transcript if t.get("role", "").lower() in ("candidate", "user")
        ]

        if self.client and candidate_turns:
            try:
                result = await self._generate_with_gemini(
                    transcript=transcript,
                    current_stage=current_stage,
                    interviewer_persona=interviewer_persona,
                )
                if result:
                    return result
            except Exception as exc:
                logger.warning("Gemini adaptive follow-up synthesis failed: %s. Using deterministic fallback.", exc)

        return self.select_next_question(transcript, current_stage=current_stage)

    async def _generate_with_gemini(
        self,
        transcript: list[dict[str, Any]],
        current_stage: str,
        interviewer_persona: dict[str, Any] | None = None,
    ) -> AdaptiveQuestionResult | None:
        interviewer_name = (interviewer_persona or {}).get("name") or "Alex Rivera"
        interviewer_title = (interviewer_persona or {}).get("title") or "Staff Distributed Systems Architect"
        interviewer_style = (interviewer_persona or {}).get("questioning_style") or "Socratic, analytical, direct, probes on edge cases"

        formatted_turns = []
        for t in transcript[-8:]:
            role = "Interviewer" if t.get("role") in ("interviewer", "assistant") else "Candidate"
            formatted_turns.append(f"{role}: {t.get('text', '')}")
        history_text = "\n".join(formatted_turns)

        candidate_turns = [t for t in transcript if t.get("role", "").lower() in ("candidate", "user")]
        last_candidate_turn = candidate_turns[-1].get("text", "") if candidate_turns else ""

        coverage = self.track_competency_coverage(transcript)
        unexplored = [c.name for c in self.session_plan.competency_plans if coverage.get(c.name, CompetencyCoverageStatus(competency_name=c.name)).status == "unexplored"]
        target_focus = unexplored[0] if unexplored else "system trade-offs and operational resilience"

        prompt = f"""You are {interviewer_name}, {interviewer_title} conducting a high-stakes technical interview on FitCheck.
Questioning Style: {interviewer_style}
Current Stage: {current_stage}
Difficulty Mode: {self.difficulty.upper()} ({self.session_plan.difficulty_config.tone})
Rubric Focus: {target_focus}

CONVERSATION TRANSCRIPT:
{history_text}

LATEST CANDIDATE ANSWER:
"{last_candidate_turn}"

OBJECTIVE:
Generate your immediate verbal response as {interviewer_name}.
- Ground your question directly in what the candidate just said. Challenge any hand-waving, unverified assumptions, or missing failure modes.
- If they gave an architectural claim, ask them to justify the trade-off or explain how it handles a specific disaster/bottleneck.
- Keep the response concise (2-3 sentences), direct, and spoken naturally for low-latency text-to-speech.
- Ask ONE focused question.
"""
        response = await self.client.aio.models.generate_content(
            model="gemini-3.5-flash-lite",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.3,
                max_output_tokens=150,
            ),
        )
        text = response.text.strip()
        if text:
            if text.startswith('"') and text.endswith('"'):
                text = text[1:-1].strip()
            return AdaptiveQuestionResult(
                question=text,
                stage=current_stage,
                targeted_competency=target_focus,
                rationale=f"Gemini Socratic follow-up grounded in candidate answer as {interviewer_name}.",
                is_follow_up=True,
                difficulty_tone=self.session_plan.difficulty_config.tone,
            )
        return None

    def _is_duplicate_question(self, new_question: str, past_questions: list[str]) -> bool:
        """Checks for substantial semantic and keyword overlap with previous questions."""
        def tokenize(text: str) -> set[str]:
            words = re.findall(r"\b[A-Za-z]{4,}\b", text.lower())
            stopwords = {"what", "when", "where", "which", "would", "could", "about", "your", "with", "have", "that"}
            return set(w for w in words if w not in stopwords)

        new_tokens = tokenize(new_question)
        if not new_tokens:
            return False

        for past_q in past_questions:
            past_tokens = tokenize(past_q)
            if not past_tokens:
                continue
            intersection = new_tokens.intersection(past_tokens)
            similarity = len(intersection) / max(len(new_tokens), len(past_tokens))
            if similarity > 0.65:
                return True
        return False
