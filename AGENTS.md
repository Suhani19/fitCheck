# FitCheck Engineering Instructions

## Product

FitCheck is an AI-powered, real-time interview simulation and candidate screening platform.

FitCheck is not a generic AI chatbot or a toy persona companion.

The core product experience is:

Target Job & Rubric → Interviewer Pairing → Real-Time Socratic Interview → Evidence-Based Evaluation → Longitudinal Skill Growth.

A candidate selects or defines a target job position and evaluation rubric, prepares in a hardware readiness chamber, and enters a live, low-latency, bidirectional voice interview with an AI bar-raiser.

The interviewer should:
- maintain a consistent professional interviewer persona (e.g., Staff Distributed Systems Architect, Bar-Raiser, Engineering Manager)
- conduct rigorous Socratic follow-ups and push back on shallow answers
- evaluate candidate competencies objectively against concrete rubric criteria
- ground evaluations with exact candidate transcript quotes
- maintain persistent Candidate Practice Memory across sessions to detect recurring growth areas
- communicate with natural voice inflection, real-time interruption handling, and pacing

---

# Core Interviewer Personas

FitCheck includes standardized, realistic interview personas:

1. **Alex Rivera (Staff Distributed Systems Architect)**
   - Rigorous, analytical, direct.
   - Probes deep on scalability, consensus protocols, failure modes, trade-offs, and edge cases.
   - Socratic pushback style: challenges architectural hand-waving and unverified assumptions.

2. **Priya Sharma (Principal Engineering Manager)**
   - Structured, empathetic, bar-raising.
   - Specializes in behavioral leadership, conflict resolution, ownership, cross-functional execution, and STAR framework depth.
   - Pushes beyond rehearsed answers to uncover genuine candidate agency.

3. **Marcus Vance (Lead System Security Engineer)**
   - Thorough, skeptical, detail-oriented.
   - Specializes in threat modeling, zero-trust design, auth workflows, and defense-in-depth.

4. **Elena Rostova (Senior Algorithm Specialist)**
   - Precise, encouraging, math-grounded.
   - Evaluates complexity analysis, dynamic programming, invariant verification, and data structures.

All interviewer personas are driven by dynamic configuration and database records. The application architecture MUST NOT contain persona-specific hardcoded business logic.

The interviewer system must support arbitrary customized personas, company tracks, and job rubrics.

---

# Architecture Principles

## Interview Session Definition

An interview session contains:
- candidate identity and resume background
- target job profile and seniority level
- evaluation rubric criteria and scoring weights
- selected interviewer persona and voice identity
- conversational difficulty and strictness profile
- session mode (full technical, rapid drill, behavioral)

## Interview Runtime State

Runtime state is separate from session definitions.

Runtime state contains:
- active Agora RTC channel and WebRTC streaming state
- bidirectional speech audio buffers
- live real-time transcript turns (candidate vs. interviewer)
- conversational phase (greeting, deep-dive questions, Socratic follow-ups, candidate questions, wrap-up)
- candidate practice context and previous session weaknesses

## Candidate Practice Memory

Memory is persistent information retained across practice sessions to empower candidate growth.

Memory items include:
- identified technical weaknesses (e.g., missed single-point-of-failure in load balancer)
- communication patterns (e.g., filler words, rushing, incomplete STAR answers)
- conceptual mastery milestones
- historical scorecard progression

Do not blindly store raw audio streams or sensitive personal information as long-term memory. Retain actionable candidate performance metadata and provide full candidate privacy transparency (including inspection and GDPR deletion).

## Evaluation & Scoring

Evaluations must be evidence-based and objective:
- overall score (0–100 scale)
- key competencies evaluated against target job rubrics
- concrete evidence quotes cited directly from the interview transcript
- actionable strengths and targeted remediation drills

---

# AI Architecture

Do not couple FitCheck to a single AI vendor.

Use provider abstractions.

Primary initial providers:
- **Google Gemini**: Gemini 2.5 Flash / Gemini 3.8 Live for real-time intelligence, streaming voice generation, and comprehensive post-interview rubric evaluation.
- **Agora**: Agora RTC & Cloud Agent infrastructure for ultra-low latency, bidirectional real-time audio communication.

Voice and LLM providers must be abstracted so that specialized low-latency speech providers or alternative LLM evaluation models can be plugged in seamlessly.

---

# Core Systems

The backend contains these conceptual systems:
- **Job & Rubric Engine**: Manages target roles, job descriptions, and criteria matrices.
- **Interviewer Engine**: Manages persona definitions, voice configurations, and custom persona personalization.
- **Session Runtime**: Manages live Agora RTC channels, Gemini Live agents, and transcript turn flushing.
- **Evaluation Engine**: Analyzes transcripts against job rubrics using structured LLM outputs to generate bento scorecards.
- **Candidate Practice Memory**: Persists longitudinal performance insights and tracks skill improvement.
- **Analytics & Remediation Engine**: Generates customized learning roadmaps and targeted sparring drills.

Build incrementally and maintain modular separation.

---

# Product UX

The primary candidate journey spans:
1. **Public Landing Page**: Value proposition, persona previews, transparent tracks.
2. **Candidate Command Center**: Telemetry, readiness stats, active target job, quick launch.
3. **Target Jobs & Rubrics**: Curated & custom job specifications with AI rubric generation.
4. **Interviewer Library**: Standardized personas and custom interviewer personalizer.
5. **Hardware Readiness Chamber**: Audio input dBFS metering, chime test, latency diagnostics.
6. **Live Voice Interview Room**: Real-time WebRTC audio, dynamic transcript, question spotlight.
7. **Evaluation Scorecard**: Multi-dimension scoring, evidence quotes, remediation drills.
8. **Interview History Archive**: Comprehensive past session logs and scorecard reviews.
9. **Skill Analytics & Learning Plan**: Longitudinal progress charts and targeted practice drills.
10. **Candidate Profile & Settings**: Background credentials, audio device configuration, memory privacy controls.

---

# Important Engineering Rules

1. Inspect existing code before modifying it.

2. Do not rewrite working code unnecessarily.

3. Do not delete existing functionality without explaining why.

4. Reuse existing dependencies and architecture where reasonable.

5. Keep domain logic separate from UI.

6. Keep provider integrations behind interfaces/adapters.

7. Never expose API keys in the Flutter application.

8. Never commit secrets.

9. Use environment variables for credentials.

10. Do not invent third-party APIs or SDK parameters. Verify them against current official documentation.

11. Keep the application runnable after every milestone.

12. Do not implement future functionality unless explicitly requested.

13. Prefer simple implementations over premature abstraction.

14. Do not create persona-specific hardcoded branching logic.

15. Write tests for important backend/domain logic.

16. Run relevant tests/builds after changes.

17. When a task is ambiguous, inspect the repository first and explain the ambiguity before making large architectural changes.

18. **Non-destructive migration rule**: Never delete reusable infrastructure (Agora, Gemini, speech, database models) or drop legacy user data. Migrate cleanly with backward-compatible adapters.

---

# Product Quality Bar

The goal is not to build a toy conversational demo.

The goal is to make the candidate feel:

"This is the most realistic, rigorous, and constructive technical interview practice I have ever experienced."

If a feature makes the interview simulation more authentic and actionable, prioritize it.

If a feature merely adds superficial chatbot fluff, deprioritize it.