from __future__ import annotations

import io
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.core.auth import AuthenticatedUser, get_current_user
from app.db.database import Base, get_db
from app.db.models import UserModel
from app.db.seed_presets import seed_interviewer_presets
from app.domain.schemas import (
    DEFAULT_SIMULATION_DISCLAIMER,
    ResumeExtractionResult,
    RubricGenerationRequest,
    RubricGenerationResponse,
)
from app.main import app
from app.services.interviewer_personalizer import InterviewerPersonalizerService
from app.services.resume_extractor import ResumeExtractorService
from app.services.rubric_generator import RubricGeneratorService


@pytest.fixture
def test_db_session():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()
    seed_interviewer_presets(db)

    db.add(UserModel(id="user-candidate-1", email="candidate1@test.com", display_name="User 1"))
    db.add(UserModel(id="user-candidate-2", email="candidate2@test.com", display_name="User 2"))
    db.commit()

    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def client(test_db_session):
    def override_get_db():
        yield test_db_session

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


def make_user(uid: str):
    return AuthenticatedUser(uid=uid, email=f"{uid}@test.com", display_name=uid)


# ===========================================================================
# Workstream 1: Candidate Profile & Resume Ingestion Tests
# ===========================================================================


def test_candidate_crud_and_editing(client):
    """Verifies candidate creation, retrieval, review/editing, and deletion."""
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-1")

    # 1. Create candidate
    create_payload = {
        "full_name": "Dev Sharma",
        "headline": "Full-Stack Engineer",
        "resume_text": "Experienced full-stack engineer with Python and Flutter.",
        "skills": ["Python", "Flutter", "PostgreSQL"],
        "work_experience": [
            {
                "company": "Acme Corp",
                "role": "Software Engineer",
                "start_date": "2021",
                "end_date": "Present",
                "description": "Built distributed backend services.",
                "technologies": ["Python", "FastAPI"],
            }
        ],
        "projects": [
            {
                "name": "Cloud Monitor",
                "description": "Real-time metrics dashboard.",
                "technologies": ["Flutter", "Go"],
            }
        ],
        "education": [
            {
                "institution": "National Institute of Technology",
                "degree": "B.Tech",
                "field_of_study": "Computer Science",
                "graduation_year": "2021",
            }
        ],
        "github_username": "devsharma",
    }
    resp = client.post("/api/v1/candidates", json=create_payload)
    assert resp.status_code == 201
    cand_id = resp.json()["id"]
    assert resp.json()["full_name"] == "Dev Sharma"
    assert len(resp.json()["skills"]) == 3
    assert len(resp.json()["work_experience"]) == 1
    assert len(resp.json()["projects"]) == 1
    assert len(resp.json()["education"]) == 1

    # 2. Candidate review and edit (e.g. updating skills and headline)
    update_payload = {
        "headline": "Lead Full-Stack Architect",
        "skills": ["Python", "Flutter", "PostgreSQL", "Docker", "Kubernetes"],
    }
    resp = client.put(f"/api/v1/candidates/{cand_id}", json=update_payload)
    assert resp.status_code == 200
    assert resp.json()["headline"] == "Lead Full-Stack Architect"
    assert len(resp.json()["skills"]) == 5

    # 3. List candidates
    resp = client.get("/api/v1/candidates")
    assert resp.status_code == 200
    assert len(resp.json()) == 1
    assert resp.json()[0]["id"] == cand_id

    # 4. Delete candidate
    resp = client.delete(f"/api/v1/candidates/{cand_id}")
    assert resp.status_code == 200

    resp = client.get(f"/api/v1/candidates/{cand_id}")
    assert resp.status_code == 404


def test_candidate_ownership_isolation(client):
    """Verifies that User 2 cannot view, edit, or delete User 1's candidate."""
    # Create candidate as User 1
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-1")
    resp = client.post(
        "/api/v1/candidates",
        json={"full_name": "Alice Wonderland", "skills": ["Python"]},
    )
    assert resp.status_code == 201
    cand_id = resp.json()["id"]

    # Attempt cross-user access as User 2
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-2")

    # Read
    resp = client.get(f"/api/v1/candidates/{cand_id}")
    assert resp.status_code == 404

    # Update
    resp = client.put(f"/api/v1/candidates/{cand_id}", json={"full_name": "Hacked Name"})
    assert resp.status_code == 404

    # Delete
    resp = client.delete(f"/api/v1/candidates/{cand_id}")
    assert resp.status_code == 404

    # Upload resume attachment
    files = {"file": ("test.txt", b"New resume content", "text/plain")}
    resp = client.post(f"/api/v1/candidates/{cand_id}/upload-resume", files=files)
    assert resp.status_code == 404


def test_resume_text_parsing_and_extraction(client):
    """Tests resume text upload, parsing, and structured extraction."""
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-1")

    resume_text = """
Jane Doe
Senior Backend Engineer
Email: jane.doe@example.com

SKILLS:
Python, FastAPI, Docker, PostgreSQL, Redis, Kubernetes, AWS

WORK EXPERIENCE:
Senior Software Engineer - TechCorp
Built low-latency streaming microservices in Python and Redis.
Led team of 4 engineers and improved API throughput by 40%.

Software Engineer - StartupX
Developed customer-facing REST APIs and managed PostgreSQL migrations.

PROJECTS:
Distributed Task Queue
Lightweight distributed task scheduler using Python and Redis.

EDUCATION:
University of California, Berkeley
B.S. in Computer Science, 2020
"""
    # Test /candidates/parse-text
    resp = client.post("/api/v1/candidates/parse-text", json={"text": resume_text})
    assert resp.status_code == 200
    data = resp.json()
    assert "full_name" in data
    assert len(data["skills"]) > 0
    assert "Python" in data["skills"]
    assert "PostgreSQL" in data["skills"]
    assert len(data["work_experience"]) > 0
    assert len(data["projects"]) > 0
    assert len(data["education"]) > 0


def test_resume_file_upload_validation(client):
    """Tests file size limits, disallowed file extensions, and empty text validation."""
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-1")

    # 1. Reject invalid file extension (.exe)
    files = {"file": ("malware.exe", b"fake binary executable content", "application/octet-stream")}
    resp = client.post("/api/v1/candidates/upload-resume", files=files)
    assert resp.status_code == 400
    assert "Unsupported file type" in resp.json()["detail"]

    # 2. Reject empty / too short text
    files = {"file": ("empty.txt", b"   short   ", "text/plain")}
    resp = client.post("/api/v1/candidates/upload-resume", files=files)
    assert resp.status_code == 400
    assert "too short" in resp.json()["detail"]

    # 3. Reject oversized file (> 5MB)
    large_content = b"A" * (6 * 1024 * 1024)
    files = {"file": ("large_resume.txt", large_content, "text/plain")}
    resp = client.post("/api/v1/candidates/upload-resume", files=files)
    assert resp.status_code == 400
    assert "exceeds" in resp.json()["detail"]


def test_pdf_resume_upload_extraction(client):
    """Tests uploading and parsing a valid binary PDF resume."""
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-1")

    raw_pdf = b"""%PDF-1.4
1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj
3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >> endobj
4 0 obj << /Length 44 >> stream
BT /F1 12 Tf 100 700 Td (Rohan Sharma Python Developer) Tj ET
endstream endobj
5 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj
xref
0 6
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000244 00000 n 
0000000338 00000 n 
trailer << /Size 6 /Root 1 0 R >>
startxref
407
%%EOF
"""
    files = {"file": ("rohan_resume.pdf", raw_pdf, "application/pdf")}
    resp = client.post("/api/v1/candidates/upload-resume", files=files)
    assert resp.status_code == 200
    data = resp.json()
    assert "Python" in data["skills"]
    assert "Rohan" in data["full_name"]



def test_attach_resume_to_candidate_flow(client):
    """Tests creating candidate, uploading a text resume, and verifying profile population."""
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-1")

    # 1. Create candidate
    resp = client.post(
        "/api/v1/candidates",
        json={"full_name": "Rohan Verma"},
    )
    assert resp.status_code == 201
    cand_id = resp.json()["id"]

    # 2. Upload and attach resume
    resume_content = (
        "Rohan Verma\nStaff Systems Engineer\n"
        "Skills: Python, Go, Docker, Kubernetes, PostgreSQL\n"
        "Experience: Tech Solutions - Staff Engineer\n"
        "Projects: Mesh Network Router\n"
        "Education: Delhi Technological University"
    )
    files = {"file": ("rohan_resume.txt", resume_content.encode("utf-8"), "text/plain")}
    resp = client.post(f"/api/v1/candidates/{cand_id}/upload-resume", files=files)
    assert resp.status_code == 200
    updated_cand = resp.json()
    assert updated_cand["raw_resume_filename"] == "rohan_resume.txt"
    assert "Python" in updated_cand["skills"]
    assert len(updated_cand["work_experience"]) > 0


@pytest.mark.asyncio
async def test_resume_extractor_service_mock_gemini():
    """Verifies that ResumeExtractorService properly processes structured Gemini responses."""
    mock_gemini_response = MagicMock()
    mock_gemini_response.text = (
        '{"full_name": "Priya Rao", "headline": "Staff AI Engineer", '
        '"skills": ["Python", "PyTorch", "Gemini", "FastAPI"], '
        '"work_experience": [{"company": "AI Labs", "role": "Research Scientist", "start_date": "2022", "end_date": "Present", "description": "Trained multimodal LLMs", "technologies": ["PyTorch"]}], '
        '"projects": [{"name": "FitCheck Agent", "description": "Real-time speech interview platform", "technologies": ["FastAPI", "Agora"], "url": "https://github.com/fitcheck"}], '
        '"education": [{"institution": "IIT Bombay", "degree": "M.Tech", "field_of_study": "Computer Science", "graduation_year": "2022"}], '
        '"raw_text_preview": null, "extraction_notes": null}'
    )

    service = ResumeExtractorService(api_key="mock_key")
    service.client = MagicMock()
    service.client.aio.models.generate_content = AsyncMock(return_value=mock_gemini_response)

    result = await service.extract_structured_data("Priya Rao resume text sample with sufficient length")
    assert result.full_name == "Priya Rao"
    assert result.headline == "Staff AI Engineer"
    assert "PyTorch" in result.skills
    assert len(result.work_experience) == 1
    assert result.work_experience[0].company == "AI Labs"
    assert len(result.projects) == 1
    assert len(result.education) == 1


# ===========================================================================
# Workstream 2: Jobs & Competency Rubrics Tests
# ===========================================================================


def test_job_crud_and_competencies(client):
    """Verifies job creation, updating competencies and required skills, and deletion."""
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-1")

    # 1. Create job
    job_payload = {
        "title": "Senior Distributed Systems Engineer",
        "seniority": "senior",
        "description": "Design and operate global telemetry and streaming pipelines.",
        "required_skills": ["Go", "Kafka", "PostgreSQL", "Kubernetes"],
        "competencies": [
            {
                "name": "System Scalability & Partitioning",
                "description": "Understanding high-throughput message streaming and partitioning.",
                "criteria": [
                    "Articulates horizontal partitioning and rebalancing strategies.",
                    "Explains at-least-once vs exactly-once delivery guarantees.",
                ],
                "weight": 1.5,
            }
        ],
    }
    resp = client.post("/api/v1/jobs", json=job_payload)
    assert resp.status_code == 201
    job_id = resp.json()["id"]
    assert resp.json()["title"] == "Senior Distributed Systems Engineer"
    assert len(resp.json()["required_skills"]) == 4
    assert len(resp.json()["competencies"]) == 1

    # 2. Update job
    resp = client.put(
        f"/api/v1/jobs/{job_id}",
        json={"title": "Staff Distributed Systems Engineer", "seniority": "staff"},
    )
    assert resp.status_code == 200
    assert resp.json()["title"] == "Staff Distributed Systems Engineer"
    assert resp.json()["seniority"] == "staff"

    # 3. List jobs
    resp = client.get("/api/v1/jobs")
    assert resp.status_code == 200
    assert len(resp.json()) == 1

    # 4. Delete job
    resp = client.delete(f"/api/v1/jobs/{job_id}")
    assert resp.status_code == 200

    resp = client.get(f"/api/v1/jobs/{job_id}")
    assert resp.status_code == 404


def test_job_ownership_isolation(client):
    """Verifies that User 2 cannot access, update, or delete User 1's job."""
    # Create job as User 1
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-1")
    resp = client.post(
        "/api/v1/jobs",
        json={"title": "Private Role", "description": "Confidential role"},
    )
    assert resp.status_code == 201
    job_id = resp.json()["id"]

    # Attempt access as User 2
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-2")

    resp = client.get(f"/api/v1/jobs/{job_id}")
    assert resp.status_code == 404

    resp = client.put(f"/api/v1/jobs/{job_id}", json={"title": "Hacked Title"})
    assert resp.status_code == 404

    resp = client.delete(f"/api/v1/jobs/{job_id}")
    assert resp.status_code == 404


def test_generate_rubric_fallback(client):
    """Verifies that rubric generation provides structured, observable criteria even offline."""
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-1")

    payload = {
        "title": "Principal Backend Architect",
        "description": "Design core transaction engines and oversee platform reliability.",
        "seniority": "principal",
        "required_skills": ["Python", "PostgreSQL", "Kafka"],
    }
    resp = client.post("/api/v1/jobs/generate-rubric", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert "competencies" in data
    assert len(data["competencies"]) >= 3

    for comp in data["competencies"]:
        assert len(comp["name"]) > 0
        assert len(comp["description"]) > 0
        assert len(comp["criteria"]) >= 2
        assert comp["weight"] > 0


@pytest.mark.asyncio
async def test_rubric_generator_service_mock_gemini():
    """Verifies that RubricGeneratorService parses Gemini structured responses and validates schema."""
    mock_gemini_response = MagicMock()
    mock_gemini_response.text = (
        '{"competencies": ['
        '{"name": "API Scalability", "description": "Designing high throughput endpoints", "criteria": ["Balances caching vs staleness", "Designs idempotent mutation endpoints"], "weight": 1.2}, '
        '{"name": "Database Concurrency", "description": "Managing locks and transactions", "criteria": ["Explains isolation levels", "Analyzes deadlock scenarios"], "weight": 1.0}'
        ']}'
    )

    service = RubricGeneratorService(api_key="mock_key")
    service.client = MagicMock()
    service.client.aio.models.generate_content = AsyncMock(return_value=mock_gemini_response)

    req = RubricGenerationRequest(
        title="Senior Backend Engineer",
        description="Build high-performance REST APIs",
        seniority="senior",
        required_skills=["PostgreSQL"],
    )
    result = await service.generate_rubric(req)
    assert len(result.competencies) == 2
    assert result.competencies[0].name == "API Scalability"
    assert len(result.competencies[0].criteria) == 2


# ===========================================================================
# Workstream 3: Interviewer Presets & Personalization Tests
# ===========================================================================


def test_interviewer_presets_globally_readable(client):
    """Built-in presets must be visible to all authenticated users."""
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-1")

    resp = client.get("/api/v1/interviewers")
    assert resp.status_code == 200
    interviewers = resp.json()
    preset_ids = [i["id"] for i in interviewers if i["is_preset"]]
    assert "sarah-em-001" in preset_ids
    assert "marcus-arch-001" in preset_ids
    assert "alex-lead-001" in preset_ids

    # Sarah Chen preset should have bio, provenance, and simulation disclaimer
    sarah = next(i for i in interviewers if i["id"] == "sarah-em-001")
    assert sarah["bio"] is not None
    assert "FitCheck Built-in Presets" in sarah["provenance"]["source"]
    assert DEFAULT_SIMULATION_DISCLAIMER in sarah["provenance"]["disclaimer"]


def test_interviewer_preset_immutability(client):
    """Presets cannot be updated or deleted by users."""
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-1")

    # Update attempt
    resp = client.put("/api/v1/interviewers/sarah-em-001", json={"name": "Hacked Sarah"})
    assert resp.status_code == 404

    # Delete attempt
    resp = client.delete("/api/v1/interviewers/sarah-em-001")
    assert resp.status_code == 404


def test_custom_interviewer_crud_and_isolation(client):
    """Users can create, view, edit, and delete their own interviewers, with strict multi-tenant isolation."""
    # Create as User 1
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-1")
    create_payload = {
        "name": "Custom Tech Lead",
        "title": "Director of Platform Engineering",
        "bio": "Oversees platform reliability and cloud infrastructure.",
        "company_context": "Fintech Enterprise",
        "questioning_style": "rigorous",
        "voice_id": "Fenrir",
        "provenance": {
            "verified_facts": [{"fact": "Leads platform team", "verified": True}],
            "inferred_style": {"focus_areas": ["Reliability", "SRE"]},
            "disclaimer": DEFAULT_SIMULATION_DISCLAIMER,
        },
    }
    resp = client.post("/api/v1/interviewers", json=create_payload)
    assert resp.status_code == 201
    custom_id = resp.json()["id"]
    assert resp.json()["is_preset"] is False

    # User 1 can update custom interviewer
    resp = client.put(f"/api/v1/interviewers/{custom_id}", json={"questioning_style": "conversational"})
    assert resp.status_code == 200
    assert resp.json()["questioning_style"] == "conversational"

    # User 2 cannot access, update, or delete User 1's custom interviewer
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-2")

    resp = client.get(f"/api/v1/interviewers/{custom_id}")
    assert resp.status_code == 404

    resp = client.put(f"/api/v1/interviewers/{custom_id}", json={"name": "Attacker"})
    assert resp.status_code == 404

    resp = client.delete(f"/api/v1/interviewers/{custom_id}")
    assert resp.status_code == 404

    # User 1 can delete
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-1")
    resp = client.delete(f"/api/v1/interviewers/{custom_id}")
    assert resp.status_code == 200


def test_interviewer_personalization_provenance(client):
    """Personalization endpoint must separate verified facts from inferred style and attach simulation disclaimer."""
    app.dependency_overrides[get_current_user] = lambda: make_user("user-candidate-1")

    payload = {
        "name": "Dr. Aris Thorne",
        "title": "VP of Engineering",
        "company_context": "Autonomous Systems Research",
        "public_url": "https://example.com/aris-thorne",
        "user_notes": "Experienced leader in safety-critical robotics and fault-tolerant computing.",
        "questioning_style": "rigorous",
    }
    resp = client.post("/api/v1/interviewers/personalize", json=payload)
    assert resp.status_code == 200
    data = resp.json()
    assert data["name"] == "Dr. Aris Thorne"
    assert data["title"] == "VP of Engineering"

    # Verify provenance structure
    prov = data["provenance"]
    assert "verified_facts" in prov
    assert len(prov["verified_facts"]) >= 1
    assert prov["verified_facts"][0]["verified"] is True
    assert "inferred_style" in prov
    assert prov["inferred_style"]["simulated"] is True

    # Disclaimer must be explicitly present
    assert DEFAULT_SIMULATION_DISCLAIMER in prov["disclaimer"]
