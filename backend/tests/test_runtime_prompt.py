from app.agents.runtime_prompt import build_character_system_prompt
from app.models.character import (
    Behavior,
    InterviewerPersona,
    Personality,
    Story,
    VoiceProfile,
)
from app.models.demo_character import raj


def test_build_character_system_prompt_generic():
    maya = InterviewerPersona(
        id="maya-teacher-002",
        name="Maya",
        age=30,
        role="Language Teacher",
        appearance="Stargazer with spectacles.",
        personality=Personality(traits=["calm", "patient", "thoughtful"]),
        story=Story(backstory="Explores literature and teaches languages."),
        behavior=Behavior(rules=["Teach with empathy", "Encourage questions"]),
        voice=VoiceProfile(
            description="Calm and soothing voice",
            tone="Calm",
            speaking_style="Thoughtful and patient",
        ),
        languages=["English", "Spanish"],
    )

    prompt = build_character_system_prompt(maya)

    assert "You are Maya." in prompt
    assert "Language Teacher" in prompt
    assert "calm, patient, thoughtful" in prompt
    assert "Explores literature and teaches languages." in prompt
    assert "- Teach with empathy" in prompt
    assert "English, Spanish" in prompt

    # Verify zero Raj-specific strings in Maya prompt
    assert "Raj" not in prompt
    assert "roommate" not in prompt.lower()
    assert "biryani" not in prompt.lower()
    assert "arre bhai" not in prompt.lower()
    assert "indian guy" not in prompt.lower()


def test_build_character_system_prompt_raj():
    prompt = build_character_system_prompt(raj)
    assert "You are Raj." in prompt
    assert "Roommate" in prompt
    assert "sarcastic" in prompt
