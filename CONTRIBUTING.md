# Contributing to FitCheck

Thank you for your interest in contributing to **FitCheck** — an AI-powered, real-time interview simulation and candidate screening platform.

We welcome contributions that maintain technical rigor, clean architectural boundaries, and high code quality.

---

## Development Setup

### 1. Prerequisites
- **Flutter SDK**: `^3.47` (Dart `^3.13`)
- **Python**: `>= 3.10` (Python `3.13` recommended)
- **Git**
- Optional: **PostgreSQL** or Docker for production relational persistence (defaults to local SQLite `fitcheck.db` if `DATABASE_URL` is omitted).

### 2. Backend Setup
```bash
cd backend
python -m venv .venv

# Activate virtual environment
# Windows (PowerShell):
.venv\Scripts\Activate.ps1
# Windows (cmd):
.venv\Scripts\activate.bat
# macOS / Linux:
source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env
# Configure your GEMINI_API_KEY, AGORA_*, and optional DATABASE_URL in .env
uvicorn app.main:app --reload --port 8000
```

### 3. Flutter Client Setup
```bash
# Install dependencies from root
flutter pub get

# Run on Web, Desktop, or Mobile
flutter run -d chrome
# OR
flutter run -d windows
```

---

## Core Engineering Rules

1. **Non-Destructive Migration**: Never delete reusable infrastructure (Agora WebRTC, Gemini live streaming, speech transcription adapters, database migrations) or drop legacy tables.
2. **Provider Abstraction**: Keep AI and real-time audio integrations behind clean interfaces/adapters (`FitCheckRuntimeService`, `SpeechProvider`, `AgoraService`). Never couple the product to a single proprietary vendor.
3. **No Hardcoded Persona Branching**: All interviewer personas (Marcus Vance, Sarah Chen, Alex Rivera, custom personas) must be driven dynamically by configuration and database records. Do not introduce hardcoded `if (persona == 'Marcus')` business logic.
4. **Candidate Data Isolation**: All candidate models, jobs, sessions, and practice memories must enforce strict `WHERE user_id = current_user.uid` tenant isolation. Never expose another candidate's session data.
5. **No Client-Side Secrets**: Never embed Gemini API keys, Agora customer secrets, or private service account tokens in the Flutter client application.

---

## Coding Standards

### Dart & Flutter
- Adhere to `analysis_options.yaml` (`flutter_lints`).
- Use canonical `FitCheckTheme` design tokens (`#08090C` Canvas, `#5CE2F6` Studio Cyan, `#CEBDFF` Lavender, `#5AE9AC` Emerald).
- Keep domain and networking logic decoupled from UI widgets.
- Write widget tests and unit tests for critical flightdeck workflows.

### Python & FastAPI
- Follow PEP 8 guidelines and strict type annotations.
- Keep route handlers in `app/api/v1_router.py` lean; delegate business logic to domain services (`InterviewPlannerService`, `EvaluationEngineService`, `RubricGeneratorService`).
- Use Pydantic schemas in `app/domain/schemas.py` for request validation and serialization.

---

## Pull Request Guidelines

Before submitting a pull request:
1. Ensure code passes static analysis: `flutter analyze`.
2. Ensure the Flutter test suite passes: `flutter test`.
3. Ensure backend unit and integration tests pass: `cd backend && pytest`.
4. Document any new environment variables or schema additions in `docs/`.
