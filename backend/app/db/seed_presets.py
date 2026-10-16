import logging
from sqlalchemy.orm import Session
from app.db.models import InterviewerModel

logger = logging.getLogger(__name__)

PRESET_INTERVIEWERS = [
    {
        "id": "sarah-em-001",
        "name": "Sarah Chen",
        "title": "Senior Engineering Manager",
        "bio": "Experienced engineering leader focused on resilient systems, team velocity, and post-incident learning.",
        "company_context": "Tier-1 Cloud Platform Infrastructure",
        "questioning_style": "rigorous",
        "voice_id": "Aoede",
        "is_preset": True,
        "provenance": {
            "source": "FitCheck Built-in Presets",
            "verified_facts": [
                {"fact": "Specializes in cloud platform engineering and incident response.", "source_type": "fitcheck_preset", "verified": True}
            ],
            "inferred_style": {
                "focus_areas": ["System Design", "Leadership & Ownership", "Cross-Functional Collaboration", "Failure Postmortems"],
                "simulated": True,
            },
            "disclaimer": "FitCheck provides an AI simulation for practice and preparation purposes, not the actual person's participation or endorsement.",
        },
    },
    {
        "id": "marcus-arch-001",
        "name": "Marcus Vance",
        "title": "Principal Distributed Systems Architect",
        "bio": "Specialist in large-scale concurrency, streaming pipelines, and high-availability database architectures.",
        "company_context": "High-Throughput Financial & Streaming Infrastructure",
        "questioning_style": "challenging",
        "voice_id": "Fenrir",
        "is_preset": True,
        "provenance": {
            "source": "FitCheck Built-in Presets",
            "verified_facts": [
                {"fact": "Focuses on high-throughput distributed transaction systems.", "source_type": "fitcheck_preset", "verified": True}
            ],
            "inferred_style": {
                "focus_areas": ["Concurrency & Race Conditions", "CAP Theorem Trade-Offs", "Database Indexing & Sharding", "Fault Isolation"],
                "simulated": True,
            },
            "disclaimer": "FitCheck provides an AI simulation for practice and preparation purposes, not the actual person's participation or endorsement.",
        },
    },
    {
        "id": "alex-lead-001",
        "name": "Alex Rivera",
        "title": "Staff Full-Stack Product Engineer",
        "bio": "Pragmatic product engineer with expertise in API architectures, modern web frameworks, and user experience.",
        "company_context": "Fast-Paced Consumer & Enterprise SaaS",
        "questioning_style": "conversational",
        "voice_id": "Puck",
        "is_preset": True,
        "provenance": {
            "source": "FitCheck Built-in Presets",
            "verified_facts": [
                {"fact": "Focuses on full-stack architecture and developer experience.", "source_type": "fitcheck_preset", "verified": True}
            ],
            "inferred_style": {
                "focus_areas": ["Pragmatic Architecture", "API Design & Clean Code", "Performance Optimization", "Product Intuition"],
                "simulated": True,
            },
            "disclaimer": "FitCheck provides an AI simulation for practice and preparation purposes, not the actual person's participation or endorsement.",
        },
    },
]


def seed_interviewer_presets(db: Session) -> int:
    """Idempotently seeds built-in interviewer presets."""
    seeded_count = 0
    for preset in PRESET_INTERVIEWERS:
        existing = db.query(InterviewerModel).filter(InterviewerModel.id == preset["id"]).first()
        if not existing:
            interviewer = InterviewerModel(
                id=preset["id"],
                user_id=None,  # Presets are globally accessible, not owned by a single user
                name=preset["name"],
                title=preset["title"],
                bio=preset.get("bio"),
                company_context=preset["company_context"],
                questioning_style=preset["questioning_style"],
                voice_id=preset["voice_id"],
                is_preset=True,
                provenance=preset["provenance"],
            )
            db.add(interviewer)
            seeded_count += 1
        else:
            existing.bio = preset.get("bio")
            existing.provenance = preset["provenance"]
    db.commit()
    logger.info("Seeded %d interviewer presets.", seeded_count)
    return seeded_count

