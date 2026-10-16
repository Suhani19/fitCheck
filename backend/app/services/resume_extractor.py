from __future__ import annotations

import io
import logging
import os
import re
from typing import Any

from google import genai
from google.genai import types
from pydantic import ValidationError

from app.domain.schemas import (
    EducationItem,
    ProjectItem,
    ResumeExtractionResult,
    WorkExperienceItem,
)

logger = logging.getLogger(__name__)

MAX_RESUME_FILE_SIZE = 5 * 1024 * 1024  # 5 MB
ALLOWED_EXTENSIONS = {".pdf", ".txt", ".text", ".md"}


class ResumeExtractorService:
    """Service for extracting text and structured data from candidate resumes."""

    def __init__(self, api_key: str | None = None) -> None:
        self.api_key = api_key or os.getenv("GEMINI_API_KEY")
        if self.api_key:
            self.client = genai.Client(api_key=self.api_key)
        else:
            self.client = None

    def extract_text_from_file(
        self,
        content: bytes,
        filename: str,
        content_type: str | None = None,
        max_size: int = MAX_RESUME_FILE_SIZE,
    ) -> str:
        """Safely extracts clean plain text from an uploaded resume file (PDF or text)."""
        if len(content) > max_size:
            raise ValueError(f"File size exceeds the {max_size // (1024 * 1024)}MB limit.")

        ext = os.path.splitext(filename.lower())[1]
        if ext not in ALLOWED_EXTENSIONS:
            raise ValueError(
                f"Unsupported file type '{ext}'. Supported formats: {', '.join(sorted(ALLOWED_EXTENSIONS))}"
            )

        if ext == ".pdf" or (content_type and "pdf" in content_type.lower()):
            text = self._extract_text_from_pdf(content)
        else:
            text = self._extract_text_from_raw_bytes(content)

        clean_text = text.strip()
        if len(clean_text) < 10:
            raise ValueError("Extracted resume text is empty or too short to analyze.")

        return clean_text

    def _extract_text_from_pdf(self, content: bytes) -> str:
        try:
            import pypdf
        except ImportError:
            raise RuntimeError("pypdf is not installed. PDF extraction is unavailable.")

        try:
            reader = pypdf.PdfReader(io.BytesIO(content))
        except Exception as e:
            raise ValueError(f"Invalid or corrupted PDF file: {str(e)}")

        if reader.is_encrypted:
            try:
                # Attempt empty password decryption
                decrypted = reader.decrypt("")
                if not decrypted:
                    raise ValueError("Encrypted PDF files are not supported.")
            except Exception:
                raise ValueError("Encrypted PDF files are not supported.")

        extracted_pages = []
        for idx, page in enumerate(reader.pages):
            try:
                page_text = page.extract_text()
                if page_text:
                    extracted_pages.append(page_text)
            except Exception as e:
                logger.warning("Failed to extract page %d from PDF: %s", idx, str(e))

        combined = "\n\n".join(extracted_pages).strip()
        if not combined:
            raise ValueError("Could not extract any readable text from this PDF file.")
        return combined

    def _extract_text_from_raw_bytes(self, content: bytes) -> str:
        for encoding in ("utf-8", "utf-8-sig", "latin-1"):
            try:
                return content.decode(encoding)
            except UnicodeDecodeError:
                continue
        raise ValueError("Could not decode text file with supported encodings.")

    async def extract_structured_data(self, resume_text: str) -> ResumeExtractionResult:
        """Extracts structured candidate profile data from resume text using Gemini or deterministic fallback."""
        if not resume_text or len(resume_text.strip()) < 10:
            raise ValueError("Resume text is empty or too short.")

        if self.client:
            try:
                return await self._extract_with_gemini(resume_text)
            except Exception as e:
                logger.warning(
                    "Gemini structured resume extraction failed or timed out: %s. Falling back to rule-based parser.",
                    str(e),
                )

        return self._heuristic_fallback_extraction(resume_text)

    async def _extract_with_gemini(self, resume_text: str) -> ResumeExtractionResult:
        prompt = f"""You are an expert technical recruiter and resume ingestion parser for FitCheck.
Analyze the following resume and extract high-precision structured candidate data.

Guidelines:
1. full_name: The candidate's legal or professional name.
2. headline: Professional title or summary headline (e.g. "Senior Backend Engineer | Distributed Systems").
3. skills: List of distinct technical and professional skills, frameworks, tools, and languages.
4. work_experience: List of past professional roles with company, role, start_date, end_date, description, and technologies.
5. projects: List of key personal or professional projects with name, description, technologies, and url (if available).
6. education: Academic degrees, institutions, fields of study, and graduation year.

Resume Text:
\"\"\"
{resume_text[:12000]}
\"\"\"
"""
        response = await self.client.aio.models.generate_content(
            model="gemini-3.5-flash-lite",
            contents=prompt,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=ResumeExtractionResult,
                temperature=0.1,
            ),
        )

        # Parse response using Pydantic validation
        result_text = response.text
        parsed = ResumeExtractionResult.model_validate_json(result_text)
        parsed.raw_text_preview = resume_text[:500]
        parsed.extraction_notes = "Extracted successfully using Gemini structured output."
        return parsed

    def _heuristic_fallback_extraction(self, resume_text: str) -> ResumeExtractionResult:
        """Deterministic rule-based parser for when AI extraction is offline or unconfigured."""
        lines = [line.strip() for line in resume_text.splitlines() if line.strip()]
        full_name = lines[0] if lines else "Candidate"
        headline = lines[1] if len(lines) > 1 and len(lines[1]) < 80 else None

        # Extract common tech keywords
        common_skills = [
            "Python", "FastAPI", "Django", "PostgreSQL", "SQLAlchemy", "Docker", "Kubernetes",
            "Go", "Rust", "Java", "TypeScript", "JavaScript", "React", "Node.js", "Flutter",
            "Dart", "AWS", "GCP", "Azure", "Git", "Redis", "GraphQL", "REST", "CI/CD",
        ]
        found_skills = []
        for skill in common_skills:
            pattern = rf"\b{re.escape(skill)}\b"
            if re.search(pattern, resume_text, re.IGNORECASE):
                found_skills.append(skill)

        # Basic section detection
        work_experience = []
        projects = []
        education = []

        current_section = None
        for line in lines[1:]:
            lower = line.lower()
            section_matched = False
            for sec_keywords, sec_name in [
                (["experience", "work history", "employment"], "work"),
                (["projects", "personal projects", "open source"], "projects"),
                (["education", "academic", "university", "degrees"], "education"),
                (["skills", "technologies", "competencies"], "skills"),
            ]:
                if any(lower.startswith(k) or f"{k}:" in lower for k in sec_keywords):
                    current_section = sec_name
                    if ":" in line:
                        line = line.split(":", 1)[1].strip()
                    else:
                        section_matched = True
                    break

            if section_matched or not line:
                continue

            if current_section == "work" and len(work_experience) < 5:
                if len(line) > 5 and not line.startswith("-") and not line.startswith("•"):
                    parts = re.split(r"[-–—|,]", line)
                    role = parts[0].strip()
                    company = parts[1].strip() if len(parts) > 1 else "Company"
                    work_experience.append(
                        WorkExperienceItem(
                            company=company,
                            role=role,
                            description=line,
                        )
                    )
            elif current_section == "projects" and len(projects) < 5:
                if len(line) > 5 and not line.startswith("-") and not line.startswith("•"):
                    projects.append(ProjectItem(name=line[:50], description=line))
            elif current_section == "education" and len(education) < 3:
                if len(line) > 5:
                    education.append(EducationItem(institution=line[:60], degree="Degree/Coursework"))

        return ResumeExtractionResult(
            full_name=full_name,
            headline=headline,
            skills=found_skills,
            work_experience=work_experience,
            projects=projects,
            education=education,
            raw_text_preview=resume_text[:500],
            extraction_notes="Parsed using rule-based fallback parser (AI service offline or unconfigured).",
        )
