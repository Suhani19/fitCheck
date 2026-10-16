# FitCheck Developer Guide

This guide details local configuration, environment setup, and development procedures for the **FitCheck** platform: an AI-powered, real-time interview simulation and candidate practice system consisting of a Flutter client and a FastAPI backend.

---

## 1. Local Prerequisites

Ensure your development environment satisfies the required toolchain versions:

| Tool | Version Requirement | Verified in Repository |
|---|---|---|
| **Flutter SDK** | `^3.47.0` | `3.47.5` |
| **Dart SDK** | `^3.13.0` | `3.13.4` |
| **Python** | `>= 3.10` | `3.13.x` |
| **Git** | `2.x` | `2.x` |

---

## 2. Backend Setup & Execution

The backend service is located in the `backend/` directory.

### 2.1 Virtual Environment Setup

From the repository root:

```bash
# Navigate to backend directory
cd backend

# Create Python virtual environment
python -m venv .venv

# Activate virtual environment
# Windows (PowerShell):
.venv\Scripts\Activate.ps1
# Windows (cmd):
.venv\Scripts\activate.bat
# macOS / Linux:
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2.2 Environment Configuration

Copy `.env.example` to `.env` inside `backend/` (or repository root):

```bash
cp .env.example .env
```

Configure your environment variables:

```dotenv
# Core AI Intelligence (Gemini Live / Rubrics / Evaluation / Memory)
GEMINI_API_KEY=your_gemini_api_key_here

# Real-Time Voice Infrastructure (Agora RTC SD-RTN)
AGORA_APP_ID=your_agora_app_id_here
AGORA_APP_CERTIFICATE=your_agora_app_certificate_here
AGORA_CUSTOMER_ID=your_agora_customer_id_here
AGORA_CUSTOMER_SECRET=your_agora_customer_secret_here

# Persistence (PostgreSQL connection string; defaults to SQLite fallback if unset)
DATABASE_URL=postgresql://user:password@localhost:5432/fitcheck

# Authentication (Optional Firebase project ID for cryptographic JWT verification)
FIREBASE_PROJECT_ID=your-firebase-project-id

# Speech Provider Override (default: "gemini")
FITCHECK_SPEECH_PROVIDER=gemini
```

> **Security Reminder**: Never commit API keys or certificates to Git. All credentials must be supplied via local environment variables. Client applications never receive Agora App Certificates or Gemini API keys.

### 2.3 Run the Backend Server

```bash
uvicorn app.main:app --reload --port 8000
```

The service will start on `http://localhost:8000`.

On startup, the backend automatically:
1. Initializes SQLAlchemy schema tables (`users`, `candidates`, `jobs`, `interviewers`, `interview_sessions`, `interview_evaluations`, `candidate_practice_memories`).
2. Seeds canonical standard interviewer presets idempotently:
   - **Alex Rivera** (Staff Distributed Systems Architect)
   - **Priya Sharma** (Principal Engineering Manager)
   - **Marcus Vance** (Lead System Security Engineer)
   - **Elena Rostova** (Senior Algorithm Specialist)
3. Invokes `legacy_migrator.py` to copy any existing legacy records into archived history tables without data loss.


### 2.4 Interactive OpenAPI Documentation

Explore and test endpoints directly via browser:
- **Swagger UI**: [http://localhost:8000/docs](http://localhost:8000/docs)
- **ReDoc**: [http://localhost:8000/redoc](http://localhost:8000/redoc)

Key API Route Groups:
- `/api/v1/candidates`: Candidate profile management and resume text parsing
- `/api/v1/jobs`: Target jobs catalog and AI rubric synthesis
- `/api/v1/interviewers`: Interviewer persona presets and AI personalization
- `/api/v1/sessions`: Session lifecycle (creation, Agora token generation, conclusion)
- `/api/v1/evaluations`: Evidence-based scorecard retrieval and analytics
- `/api/v1/memory`: Candidate Practice Memory inspection and GDPR deletion

---

## 3. Flutter Application Setup & Execution

### 3.1 Install Flutter Dependencies

From the repository root:

```bash
flutter pub get
```

### 3.2 Launching the Client

#### Web (Google Chrome)
```bash
flutter run -d chrome
```
*Connects automatically to `http://localhost:8000`.*

#### Windows Desktop
```bash
flutter run -d windows
```
*Connects automatically to `http://localhost:8000`.*

#### macOS Desktop
```bash
flutter run -d macos
```

#### Linux Desktop
```bash
flutter run -d linux
```

#### Android Emulator
```bash
flutter run -d android
```
*The Flutter app automatically uses `http://10.0.2.2:8000` when running on an Android emulator to route to the host machine's backend.*

#### Custom Backend URL Override
To point to a staging or remote backend:
```bash
flutter run --dart-define=FITCHECK_BACKEND_URL=https://api.yourfitcheckdomain.com
```

---

## 4. Resetting Local Development State

### SQLite Local Development
If running on the default local SQLite database:

```bash
# Stop backend server, then remove the local database file:
rm backend/data/fitcheck.db

# Restart backend to re-initialize schema and re-seed interviewer presets:
uvicorn app.main:app --reload --port 8000
```

### PostgreSQL Development
If running against PostgreSQL:

```sql
-- Connect to PostgreSQL and reset schema:
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
```
Restarting the FastAPI server will re-run table creation and preset seeding.

---

## 5. Verification & Testing Workflow

As part of the non-destructive FitCheck migration strategy, full test suites are executed during consolidated verification rounds:

### 5.1 Static Code Analysis
```bash
flutter analyze
```

### 5.2 Flutter Test Suite
```bash
flutter test
```
Covers:
- FitCheck Precision Studio theme tokens and widgets
- Hardware readiness audio chime, dBFS loopback visualizer, and device checks
- Socratic interviewer selection, preset deduplication, and custom persona configuration
- Live interview room streaming, transcript turn ingestion, and mute controls
- Candidate practice memory management and Right-to-be-Forgotten confirmation
- Candidate command center telemetry, skill analytics, and practice drill launch

### 5.3 Backend Pytest Suite
```bash
# Windows:
backend\.venv\Scripts\pytest backend\tests -v

# macOS / Linux:
pytest backend/tests -v
```
Covers:
- Authentication, Firebase ID token verification, and tenant isolation (`WHERE user_id = :uid`)
- Agora RTC ephemeral token issuance and expiration boundaries
- Interview planner session compilation and Socratic question generation
- Evaluation engine rubric matching with transcript quote extraction
- Memory extractor milestone and gap distillation
- Resume parsing and structured profile integration
- Legacy SQLite migrator zero-data-loss execution
