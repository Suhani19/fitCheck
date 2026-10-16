# FitCheck Database Documentation

## 1. Storage Overview

FitCheck features a dual-engine persistence layer supported by SQLAlchemy 2.0:

1. **PostgreSQL (Production / Docker)**: Configured via `DATABASE_URL` (e.g. `postgresql://fitcheck_user:password@localhost:5432/fitcheck`).
2. **SQLite (Zero-Configuration Local Development)**: Automatically used as fallback when `DATABASE_URL` is omitted (defaults to `backend/data/fitcheck.db`).

The database engine, tables, indexes, and preset interviewers are initialized automatically on startup via `app.db.database.init_db()` and `app.db.seed_presets.seed_interviewer_presets()`.

---

## 2. Entity-Relationship Diagram

```mermaid
erDiagram
    users ||--o{ candidates : "owns"
    users ||--o{ jobs : "configures"
    users ||--o{ interviewers : "creates custom"
    users ||--o{ interview_sessions : "participates in"
    users ||--o{ interview_evaluations : "receives"
    users ||--o{ candidate_practice_memories : "has recorded"

    candidates ||--o{ interview_sessions : "interviewed in"
    jobs ||--o{ interview_sessions : "targeted in"
    interviewers ||--o{ interview_sessions : "conducts"
    interview_sessions ||--|| interview_evaluations : "evaluated by"

    users {
        VARCHAR(128) id PK "Firebase UID"
        VARCHAR(255) email
        VARCHAR(255) display_name
        TIMESTAMP created_at
        TIMESTAMP updated_at
    }

    candidates {
        VARCHAR(64) id PK
        VARCHAR(128) user_id FK "Cascade delete"
        VARCHAR(255) full_name
        VARCHAR(255) headline
        TEXT resume_text
        VARCHAR(255) raw_resume_filename
        JSON skills
        JSON work_experience
        JSON projects
        JSON education
        VARCHAR(128) github_username
        JSON github_summary
        TIMESTAMP created_at
        TIMESTAMP updated_at
    }

    jobs {
        VARCHAR(64) id PK
        VARCHAR(128) user_id FK "Cascade delete"
        VARCHAR(255) title
        VARCHAR(64) seniority
        TEXT description
        JSON required_skills
        JSON competencies
        TIMESTAMP created_at
        TIMESTAMP updated_at
    }

    interviewers {
        VARCHAR(64) id PK
        VARCHAR(128) user_id FK "Null for built-in presets"
        VARCHAR(255) name
        VARCHAR(255) title
        TEXT bio
        TEXT company_context
        VARCHAR(64) questioning_style
        VARCHAR(64) voice_id
        BOOLEAN is_preset
        JSON provenance
        TIMESTAMP created_at
        TIMESTAMP updated_at
    }

    interview_sessions {
        VARCHAR(64) id PK
        VARCHAR(128) user_id FK
        VARCHAR(64) candidate_id FK
        VARCHAR(64) job_id FK
        VARCHAR(64) interviewer_id FK
        VARCHAR(64) difficulty
        VARCHAR(64) status
        VARCHAR(128) channel
        VARCHAR(128) agent_id
        JSON session_plan
        JSON transcript
        TIMESTAMP started_at
        TIMESTAMP ended_at
    }

    interview_evaluations {
        VARCHAR(64) id PK
        VARCHAR(64) session_id FK, UK
        VARCHAR(128) user_id FK
        FLOAT overall_score
        VARCHAR(64) overall_recommendation
        TEXT summary_verdict
        JSON competency_scores
        JSON observed_strengths
        JSON technical_gaps
        JSON preparation_recommendations
        JSON human_review
        TIMESTAMP created_at
    }

    candidate_practice_memories {
        VARCHAR(64) id PK
        VARCHAR(128) user_id FK
        VARCHAR(64) character_id
        VARCHAR(64) session_id
        TEXT content
        VARCHAR(64) category
        FLOAT importance
        TIMESTAMP created_at
    }
```

---

## 3. Schema Definitions

### 3.1 `candidates`
Stores candidate profile information, ingested resume text, extracted skills, and employment timelines.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Unique candidate identifier. |
| `user_id` | `VARCHAR(128)` | `NOT NULL, INDEX, FK(users.id)` | Authenticated user owner (Firebase UID). |
| `full_name` | `VARCHAR(255)` | `NOT NULL` | Candidate display name. |
| `headline` | `VARCHAR(255)` | `NULLABLE` | Professional title (e.g. *Senior Backend Engineer*). |
| `resume_text` | `TEXT` | `NULLABLE` | Raw or extracted resume text body. |
| `raw_resume_filename` | `VARCHAR(255)` | `NULLABLE` | Filename of uploaded resume. |
| `skills` | `JSON` | `DEFAULT '[]'` | Array of skill strings. |
| `work_experience` | `JSON` | `DEFAULT '[]'` | Array of work history objects (`company`, `role`, `start_date`, etc.). |
| `projects` | `JSON` | `DEFAULT '[]'` | Array of technical project objects (`name`, `description`, `technologies`). |
| `education` | `JSON` | `DEFAULT '[]'` | Array of educational history objects (`institution`, `degree`). |

---

### 3.2 `jobs`
Stores configured target jobs, hiring standard descriptions, and observable competency rubrics.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Unique job identifier (e.g. `job-dist-sys`). |
| `user_id` | `VARCHAR(128)` | `NOT NULL, INDEX, FK(users.id)` | Authenticated user owner. |
| `title` | `VARCHAR(255)` | `NOT NULL` | Job role title (e.g. *Staff Distributed Systems Architect*). |
| `seniority` | `VARCHAR(64)` | `NOT NULL, DEFAULT 'senior'` | Seniority level (`junior`, `mid`, `senior`, `staff`, `lead`). |
| `description` | `TEXT` | `NOT NULL` | Job description and hiring standards. |
| `required_skills` | `JSON` | `DEFAULT '[]'` | Core technologies required for the role. |
| `competencies` | `JSON` | `DEFAULT '[]'` | Array of structured competency rubrics with observable criteria. |

---

### 3.3 `interviewers`
Stores built-in interviewer presets (*Marcus Vance*, *Sarah Chen*, *Alex Rivera*) and custom personalized personas.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Unique persona identifier (e.g. `marcus-arch-001`). |
| `user_id` | `VARCHAR(128)` | `NULLABLE, INDEX, FK(users.id)` | Owner UID (`NULL` for global presets). |
| `name` | `VARCHAR(255)` | `NOT NULL` | Persona display name. |
| `title` | `VARCHAR(255)` | `NOT NULL` | Professional title (e.g. *Principal Distributed Systems Architect*). |
| `bio` | `TEXT` | `NULLABLE` | Interviewer background and domain authority. |
| `company_context` | `TEXT` | `NULLABLE` | Target company context (e.g. *Stripe Core Infrastructure*). |
| `questioning_style` | `VARCHAR(64)` | `NOT NULL` | Style (`conversational`, `rigorous`, `challenging`). |
| `voice_id` | `VARCHAR(64)` | `NOT NULL` | Gemini voice ID (`Fenrir`, `Aoede`, `Puck`, `Charon`, `Kore`). |
| `is_preset` | `BOOLEAN` | `DEFAULT FALSE` | True for immutable built-in personas. |
| `provenance` | `JSON` | `DEFAULT '{}'` | Metadata separating verified facts from inferred style. |

---

### 3.4 `interview_sessions`
Stores real-time interview sessions, synthesized interview plans, and transcript turns.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Unique session UUID. |
| `user_id` | `VARCHAR(128)` | `NOT NULL, INDEX, FK(users.id)` | Candidate owner UID. |
| `candidate_id` | `VARCHAR(64)` | `NOT NULL, FK(candidates.id)` | Interviewed candidate. |
| `job_id` | `VARCHAR(64)` | `NOT NULL, FK(jobs.id)` | Target job. |
| `interviewer_id` | `VARCHAR(64)` | `NOT NULL, FK(interviewers.id)` | Assigned interviewer persona. |
| `difficulty` | `VARCHAR(64)` | `NOT NULL, DEFAULT 'realistic'` | Difficulty profile (`lenient`, `realistic`, `challenging`, `expert_stress`). |
| `status` | `VARCHAR(64)` | `NOT NULL, DEFAULT 'created'` | Session status (`created`, `active`, `ended`, `failed`). |
| `channel` | `VARCHAR(128)` | `NOT NULL` | Agora RTC channel identifier. |
| `agent_id` | `VARCHAR(128)` | `NULLABLE` | Agora Cloud Agent instance ID. |
| `session_plan` | `JSON` | `DEFAULT '{}'` | Synthesized question plan and stage progression rules. |
| `transcript` | `JSON` | `DEFAULT '[]'` | Chronological list of candidate and interviewer speech turns. |
| `started_at` | `TIMESTAMP` | `NOT NULL` | Session start timestamp. |
| `ended_at` | `TIMESTAMP` | `NULLABLE` | Session completion timestamp. |

---

### 3.5 `interview_evaluations`
Stores post-interview evaluation scorecards with transcript citations.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Unique evaluation identifier. |
| `session_id` | `VARCHAR(64)` | `NOT NULL, UNIQUE, FK(interview_sessions.id)` | Evaluated session record. |
| `user_id` | `VARCHAR(128)` | `NOT NULL, INDEX, FK(users.id)` | Candidate owner UID. |
| `overall_score` | `FLOAT` | `NOT NULL` | Normalized evaluation score (0.0–100.0 or 1.0–5.0). |
| `overall_recommendation` | `VARCHAR(64)` | `NOT NULL` | Recommendation (`Strong Hire`, `Hire`, `Leaning Hire`, `No Hire`). |
| `summary_verdict` | `TEXT` | `NOT NULL` | Comprehensive executive verdict. |
| `competency_scores` | `JSON` | `NOT NULL, DEFAULT '[]'` | Array of evaluated competencies with scores and transcript quote citations. |
| `observed_strengths` | `JSON` | `DEFAULT '[]'` | Demonstrated candidate strengths. |
| `technical_gaps` | `JSON` | `DEFAULT '[]'` | Identified technical gaps and blind spots. |
| `preparation_recommendations`| `JSON` | `DEFAULT '[]'` | Prescriptive practice drills. |

---

### 3.6 `candidate_practice_memories`
Stores durable longitudinal practice insights, strengths, and recurring weak spots.

| Column | Type | Constraints | Description |
|---|---|---|---|
| `id` | `VARCHAR(64)` | `PRIMARY KEY` | Unique memory identifier. |
| `user_id` | `VARCHAR(128)` | `NOT NULL, INDEX, FK(users.id)` | Candidate owner UID. |
| `character_id` | `VARCHAR(64)` | `NULLABLE` | Interviewer persona ID who observed the fact. |
| `session_id` | `VARCHAR(64)` | `NULLABLE` | Originating session ID. |
| `content` | `TEXT` | `NOT NULL` | Plain-text memory fact or milestone. |
| `category` | `VARCHAR(64)` | `NOT NULL` | Category (`technical_fact`, `system_strength`, `growth_area`). |
| `importance` | `FLOAT` | `NOT NULL` | Socratic relevance weight (0.0–1.0). |
| `created_at` | `TIMESTAMP` | `NOT NULL` | Timestamp recorded. |

---

## 4. Archived History & Practice Memory Tables

To guarantee zero data loss during platform evolution, historical records are preserved in dedicated archive tables:

- `archived_interviewers`: Preserves historical interviewer profiles and configurations.
- `archived_sessions`: Preserves historical session logs and transcripts.
- `candidate_practice_memories`: Preserves longitudinal candidate practice memories and growth milestones.
- `archived_relationships`: Preserves historical interaction scores and trust metrics.
- `archived_metadata`: Preserves migration markers and historical metadata flags.
