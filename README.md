<div align="center">

  # FitCheck
  ### *AI-Powered Real-Time Interview Simulation & Candidate Practice Platform*

  **Realistic, rigorous Socratic technical interviews with persistent candidate growth.**

  <p align="center">
    <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.47-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" /></a>
    <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3.13-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" /></a>
    <a href="https://www.python.org"><img src="https://img.shields.io/badge/Python-3.13-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python" /></a>
    <a href="https://fastapi.tiangolo.com"><img src="https://img.shields.io/badge/FastAPI-0.115-009688?style=for-the-badge&logo=fastapi&logoColor=white" alt="FastAPI" /></a>
    <a href="https://www.postgresql.org"><img src="https://img.shields.io/badge/PostgreSQL-16-336791?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL" /></a>
    <a href="https://www.agora.io"><img src="https://img.shields.io/badge/Agora-RTC_SD--RTN-099DFD?style=for-the-badge&logo=agora&logoColor=white" alt="Agora" /></a>
    <a href="https://ai.google.dev"><img src="https://img.shields.io/badge/Google_Gemini-Live_Audio-8E75C2?style=for-the-badge&logo=google&logoColor=white" alt="Google Gemini" /></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="License: MIT" /></a>
  </p>

</div>

---

## Table of Contents

- [What is FitCheck?](#what-is-fitcheck)
- [The Product Experience](#the-product-experience)
- [Standard Interviewer Personas](#standard-interviewer-personas)
- [Feature Highlights](#feature-highlights)
- [System Architecture](#system-architecture)
- [Conversational Runtime Lifecycle](#conversational-runtime-lifecycle)
- [Technology Stack](#technology-stack)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Backend Setup](#1-backend-setup)
  - [Flutter Client Setup](#2-flutter-client-setup)
- [Environment Configuration](#environment-configuration)
- [Historical Migration Context](#historical-migration-context)
- [Verification & Testing (Batch 6)](#verification--testing-batch-6)
- [Implementation Status & Deferred Work](#implementation-status--deferred-work)
- [License](#license)

---

## What is FitCheck?

**FitCheck** is an AI-powered, real-time technical interview simulation and candidate screening platform.

FitCheck is **not** a generic chatbot, customer service agent, or toy companion.

The platform provides software engineers, engineering managers, and technical leaders with high-fidelity, high-pressure practice environments that replicate the rigor of actual bar-raiser interviews. Candidates select target roles and rubrics, verify their audio hardware, and engage in low-latency bidirectional voice interviews with AI bar-raisers who challenge hand-waving, demand trade-off analysis, and evaluate competencies objectively against concrete rubric criteria.

---

## The Product Experience

```text
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│ TARGET JOB &    │  ──►  │  INTERVIEWER    │  ──►  │   LIVE SOCRATIC │  ──►  │ EVIDENCE-BASED  │  ──►  │ LONGITUDINAL    │
│ RUBRIC PAIRING  │       │  CALIBRATION    │       │   VOICE SESSION │       │ SCORECARD       │       │ PRACTICE MEMORY │
└─────────────────┘       └─────────────────┘       └─────────────────┘       └─────────────────┘       └─────────────────┘
```

1. **Target Job & Rubric**: Define or select target engineering tracks (e.g., Staff Distributed Systems Engineer, Principal Engineering Manager) with explicit L5–L7 evaluation rubrics.
2. **Interviewer Calibration**: Pair with standard AI bar-raisers or personalize custom interviewers with calibrated strictness, Socratic pushback style, and natural voice timbres.
3. **Hardware Readiness**: Complete pre-flight audio diagnostics, verifying microphone dBFS input levels and playback chime response.
4. **Live Socratic Voice Session**: Engage in low-latency bidirectional WebRTC voice interviews powered by Agora RTC and Google Gemini Live, featuring dynamic transcripts, interruption handling, and question spotlights.
5. **Evidence-Based Evaluation**: Receive a post-session Bento scorecard providing a quantitative score (0–100), key competency ratings, exact candidate transcript quotes, and targeted remediation drills.
6. **Candidate Practice Memory**: Retain identified technical gaps and communication milestones across practice sessions so interviewers can test whether the candidate has grown.

---

## Standard Interviewer Personas

FitCheck includes standardized, realistic interview personas backed by dynamic database configurations:

* **Alex Rivera (Staff Distributed Systems Architect)**
  - *Focus*: Scalability, consensus protocols (Raft, Paxos), distributed failure modes, and CAP trade-offs.
  - *Style*: Analytical, direct; challenges architectural hand-waving and unverified assumptions.
* **Priya Sharma (Principal Engineering Manager)**
  - *Focus*: Behavioral leadership, conflict resolution, ownership, cross-functional execution, and STAR framework depth.
  - *Style*: Structured, empathetic, bar-raising; probes beyond rehearsed answers to uncover genuine agency.
* **Marcus Vance (Lead System Security Engineer)**
  - *Focus*: Threat modeling, zero-trust architectures, authentication/authorization flows, and defense-in-depth.
  - *Style*: Thorough, skeptical, detail-oriented; interrogates cryptographic boundaries and blast radiuses.
* **Elena Rostova (Senior Algorithm Specialist)**
  - *Focus*: Computational complexity analysis, dynamic programming, invariant verification, and data structures.
  - *Style*: Precise, encouraging, math-grounded; probes algorithmic correctness and optimization trade-offs.

*All personas are driven dynamically by database records. The architecture contains zero hardcoded persona logic.*

---

## Feature Highlights

### ⚡ Ultra-Low Latency Voice Interviews
Bidirectional streaming audio via **Agora SD-RTN** and **Google Gemini Live** delivers natural turn-taking, human-like voice cadence, and seamless candidate interruption handling.

### 🎯 Socratic Follow-Up Engine
The interviewer listens critically to candidate responses, detects unverified assumptions, and immediately pushes back with clarifying follow-ups rather than passively moving down a static question script.

### 📊 Evidence-Based Bento Scorecard
Post-interview scorecards grade candidate competencies on 0–100 scales and back every claim with **exact candidate transcript citations**, preventing vague or hallucinated feedback.

### 🧠 Candidate Practice Memory
Durable technical milestones, recurring communication patterns, and identified knowledge gaps persist across sessions, allowing future interviewers to tailor questioning to candidate growth areas.

### 🛡️ Candidate Data Privacy Controls
Candidates have complete transparency into their stored practice memories, including real-time inspection and per-record or bulk deletion controls under strict multi-tenant isolation.

### 🎨 Precision Studio Design System
Modern dark-mode aesthetic with refined typography (Google Fonts Inter), glassmorphism cards, hairline borders, and responsive multi-device layouts.

---

## System Architecture

FitCheck cleanly decouples client UI, conversational transport, cognitive orchestration, and persistent storage:

```mermaid
flowchart TB
    subgraph Client["Flutter Client (Dart 3.13 / Flutter 3.47)"]
        UI["Candidate Flightdeck\n(Command Center · Jobs · Library · Studio · Scorecard)"]
        CSM["CallSessionManager\n(Active Session · Background Audio · Invariant Protection)"]
        HardwareAudio["HardwareAudioService\n(dBFS Audio Metering · Chime Feedback)"]
        AgoraClient["Agora RTC Engine SDK\n(Raw Audio Stream)"]
    end

    subgraph Backend["FastAPI Backend Service (Python 3.13)"]
        API["REST Endpoints (/api/v1)\n(candidates · jobs · interviewers · sessions · evaluations · memory)"]
        Planner["InterviewPlannerService\n(Socratic Plan Synthesizer)"]
        Runtime["FitCheckRuntimeService\n(Gemini Live Prompt & Session Orchestration)"]
        EvalEngine["EvaluationEngineService\n(Transcript Quote Grounding & Scoring)"]
        Memory["MemoryExtractor\n(Candidate Practice Memory Extraction)"]
        DB[(PostgreSQL / SQLite\nTenant Isolation: WHERE user_id = :uid)]
    end

    subgraph Cloud["Cloud Infrastructure"]
        AgoraCloud["Agora SD-RTN & Cloud Agents\n(Bidirectional Audio Channel)"]
        GeminiLive["Google Gemini 2.5 Flash / Gemini Live\n(Real-Time Reasoning & Voice)"]
    end

    UI --> CSM
    CSM --> HardwareAudio
    CSM --> AgoraClient
    AgoraClient <===>|"Low-Latency WebRTC Audio"| AgoraCloud
    CSM -->|"Session Lifecycle (REST)"| API

    API --> Planner
    API --> Runtime
    API --> EvalEngine
    API --> Memory

    Planner --> GeminiLive
    Runtime --> GeminiLive
    EvalEngine --> GeminiLive
    Memory --> GeminiLive

    AgoraCloud <===>|"Bidirectional Audio Stream"| GeminiLive

    API --> DB
```

---

## Conversational Runtime Lifecycle

Every interview simulation follows an authoritative, lifecycle-managed pipeline:

```text
1. Session Initialization  ──► Client pairs candidate, job rubric, interviewer, and difficulty.
2. Hardware Readiness     ──► Candidate verifies mic dBFS loopback and audio chime playback.
3. Channel Establishment   ──► Backend provisions ephemeral Agora RTC access token and launches Cloud Agent.
4. Prompt Compilation     ──► Runtime orchestrator compiles persona directives, rubric criteria, and past memories.
5. Bidirectional Exchange  ──► Candidate and AI converse naturally with real-time turn-taking and interruption handling.
6. Session Conclusion      ──► Candidate concludes interview; client leaves Agora RTC channel.
7. Evaluation Analysis     ──► EvaluationEngine analyzes full transcript against rubric criteria.
8. Evidence Grounding      ──► Engine extracts exact transcript quotes backing each competency score.
9. Practice Memory Update  ──► MemoryExtractor isolates durable candidate facts, strengths, and growth areas.
10. Scorecard Presentation ──► Candidate inspects Bento scorecard, review metrics, and remediation drills.
```

---

## Technology Stack

| Layer | Component | Technology | Role |
|---|---|---|---|
| **Frontend** | Framework | Flutter 3.47.5 / Dart 3.13.4 | Cross-platform candidate flightdeck (Web, Desktop, Mobile) |
| | Design System | Precision Studio Theme (`FitCheckTheme`) | Obsidian surfaces (`#0E131F`), cyan accents (`#5CE2F6`), Inter typography |
| | Voice Transport | `agora_rtc_engine: ^6.6.4` | Low-latency audio transmission via Agora SD-RTN |
| | Audio Feedback | `audioplayers: ^6.0.0` | Hardware readiness chimes and audio tests |
| | Session Manager | `CallSessionManager` | Background audio preservation and single-call invariant |
| **Backend** | Framework | Python 3.13 + FastAPI 0.115 | Asynchronous REST API service |
| | Persistence | SQLAlchemy + PostgreSQL 16 / SQLite | Dual-engine persistence with strict multi-tenant isolation |
| | Token Service | `agora-token-builder` | Short-lived, cryptographic Agora RTC access token issuance |
| | Cognitive Layer | `google-genai` (Gemini 2.5 Flash / Live) | Socratic planning, voice synthesis, rubric generation, evaluation |
| | Real-Time Agent | Agora Cloud Voice Agent SDK | Low-latency WebRTC bidirectional voice pipeline |

---

## Repository Structure

```text
fitcheck/
├── README.md                      # Primary product guide & overview
├── LICENSE                        # MIT License
├── SECURITY.md                    # Security policy, credential isolation & privacy rules
├── CONTRIBUTING.md                # Development standards, guidelines & PR procedures
├── .env.example                   # Master environment configuration template
├── pubspec.yaml                   # Flutter package dependencies & asset declarations
│
├── docs/                          # Authoritative technical documentation
│   ├── ARCHITECTURE.md            # Detailed system architecture & Mermaid diagrams
│   ├── DEVELOPMENT.md             # Developer onboarding, commands, and workflows
│   ├── DATABASE.md                # Database schema, tables, and migration rules
│   ├── FITCHECK_MIGRATION_PLAN.md # Master 7-batch migration plan and status tracker
│   └── designs/                   # Design system documentation & Stitch specifications
│
├── lib/                           # Flutter application source code
│   ├── main.dart                  # Application entrypoint
│   ├── app.dart                   # FitCheckApp root widget
│   ├── core/
│   │   ├── config/                # Environment configuration resolution
│   │   ├── services/              # Hardware audio diagnostics & preferences
│   │   └── theme/                 # FitCheckTheme precision design tokens
│   ├── features/
│   │   ├── fitcheck/              # Candidate flightdeck screens, widgets & API client
│   │   │   ├── screens/           # Command Center, Target Jobs, Library, Scorecard, Analytics, Settings
│   │   │   └── widgets/           # Bento cards, navigation sidebar, hardware visualizers
│   │   └── call/                  # AgoraCallService, CallSessionManager, minimized banner
│   └── models/                    # Pydantic-aligned Dart data models & adapter helpers
│
├── backend/                       # FastAPI backend application
│   ├── requirements.txt           # Python backend dependencies
│   ├── .env.example               # Backend credential template
│   ├── app/
│   │   ├── main.py                # FastAPI routes & startup handlers
│   │   ├── api/v1_router.py       # Core REST endpoints (/api/v1)
│   │   ├── core/auth.py           # Multi-tenant authentication & token verification
│   │   ├── db/                    # SQLAlchemy models, SQLite/PostgreSQL engine & legacy migrator
│   │   ├── domain/schemas.py      # Pydantic schemas for candidates, jobs, rubrics, evaluations
│   │   ├── repositories/          # Data access layer with tenant isolation
│   │   └── services/              # Interview planner, evaluation engine, runtime orchestrator
│   └── tests/                     # Backend test suite (26 test files)
│
└── test/                          # Flutter unit, widget, and screen test suite (21 test files)
```

---

## Getting Started

### Prerequisites

* **Flutter SDK**: `^3.47.5` (Dart `^3.13.4`)
* **Python**: `3.10+` (verified on `3.13`)
* **Google Gemini API Key**: [Google AI Studio](https://aistudio.google.com/)
* **Agora Developer Account**: App ID and App Certificate from [Agora Console](https://console.agora.io/)

---

### 1. Backend Setup

```bash
# Navigate to backend directory
cd backend

# Create and activate virtual environment
python -m venv .venv

# Windows (PowerShell):
.venv\Scripts\Activate.ps1
# macOS / Linux:
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Create environment configuration
cp .env.example .env
```

Edit `backend/.env` with your API keys:
```dotenv
GEMINI_API_KEY=your_gemini_api_key_here
AGORA_APP_ID=your_agora_app_id_here
AGORA_APP_CERTIFICATE=your_agora_app_certificate_here
DATABASE_URL=postgresql://user:password@localhost:5432/fitcheck
```

Start the backend server:
```bash
uvicorn app.main:app --reload --port 8000
```
Interactive OpenAPI documentation is immediately available at [http://localhost:8000/docs](http://localhost:8000/docs).

---

### 2. Flutter Client Setup

From the repository root:

```bash
# Install dependencies
flutter pub get

# Launch on Chrome (Web):
flutter run -d chrome

# Launch on Windows Desktop:
flutter run -d windows

# Launch on Android Emulator (auto-routes to http://10.0.2.2:8000):
flutter run -d android
```

To connect to a custom backend URL:
```bash
flutter run --dart-define=FITCHECK_BACKEND_URL=https://api.yourdomain.com
```

---

## Environment Configuration

| Variable | Location | Required | Purpose |
|---|---|---|---|
| `GEMINI_API_KEY` | Backend | **Yes** | Real-time reasoning, Socratic question planning, rubric synthesis, evaluation |
| `AGORA_APP_ID` | Backend | **Yes** | Agora RTC communication and channel token generation |
| `AGORA_APP_CERTIFICATE` | Backend | **Yes** | Cryptographic RTC token signing |
| `AGORA_CUSTOMER_ID` | Backend | Optional | Agora Cloud Agent REST API authorization |
| `AGORA_CUSTOMER_SECRET` | Backend | Optional | Agora Cloud Agent REST API authorization |
| `DATABASE_URL` | Backend | Optional | PostgreSQL connection string (defaults to SQLite fallback if unset) |
| `FIREBASE_PROJECT_ID` | Backend | Optional | Firebase project ID for JWT Bearer token authentication |
| `FITCHECK_SPEECH_PROVIDER`| Backend | Optional | Speech provider (`gemini`, `sarvam`; defaults to `gemini`) |
| `FITCHECK_BACKEND_URL` | Frontend | Optional | Remote backend base URL |

---

## Standalone FitCheck Architecture

FitCheck operates as a standalone real-time technical interview simulation and candidate evaluation platform:

- **Agora Real-Time Voice Transport**: WebRTC audio streaming, volume indicators, and transcript datastream parsers are integrated into `FitCheckLiveInterviewRoom`.
- **Cognitive Distillation**: The memory extraction engine powers **Candidate Practice Memory**, preserving technical growth areas across practice sessions.
- **Dynamic Persona Construction**: The persona generation system powers the **Interviewer Personalizer**, complete with strict provenance boundaries separating verified facts from inferred conversational style.
- **Zero Data Loss Migration**: The `legacy_migrator.py` service copies legacy SQLite records into PostgreSQL `archived_*` and `candidate_practice_memories` tables on backend startup, ensuring no historical records are destroyed.

---

## Verification & Testing (Batch 6)

In accordance with the migration plan, implementation occurs in structured dependency batches (Batches 0–5) with one comprehensive consolidated verification round executed in **Batch 6**:

```bash
# 1. Flutter static analysis
flutter analyze

# 2. Flutter unit & widget test suite
flutter test

# 3. Backend pytest suite
backend\.venv\Scripts\pytest backend\tests -v
```

---

## Implementation Status & Deferred Work

- **Fully Implemented**:
  - Precision Studio design system (`FitCheckTheme`) across all active screens.
  - Candidate Command Center, Target Jobs with AI rubric generation, Interviewer Library with custom persona synthesis.
  - Hardware Readiness Chamber with live dBFS meter, test chime playback, and difficulty profiles.
  - Live Voice Interview Room with Agora RTC audio streaming, question spotlights, and transcript feeds.
  - Evidence-Based Bento Scorecard with quote citations and remediation drills.
  - Candidate Practice Memory management with right-to-be-forgotten deletion.
  - Multi-session skill analytics and longitudinal progress metrics grounded in real evaluation records.
  - Paste-text resume parsing connected directly to `POST /api/v1/candidates/parse-text`.

- **Explicitly Unverified / Deferred Work (Documented for Batch 6)**:
  - Binary resume file upload requires adding a platform-agnostic file-picker package dependency (`file_picker`) in `pubspec.yaml` during the build/test phase. The paste-text upload path is fully operational.
  - Cloud synchronization for the candidate Learning Plan currently relies on candidate-scoped local storage (`SharedPreferences`); backend cloud persistence contract is planned for a future API release.
  - Physical acoustic verification of microphone diaphragms requires real workstation hardware, as headless test runners lack physical sound cards.

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

Copyright © 2026 **Shubham Singh Ranswal**. All rights reserved.