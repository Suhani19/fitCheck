from app.models.character import (
    Behavior,
    CharacterState,
    InterviewerPersona,
    Personality,
    Story,
    VoiceProfile,
)
from app.models.demo_character import raj


def test_character_defaults_and_validation():
    character = InterviewerPersona(
        id="test-char-1",
        name="Test Character",
        role="Companion",
        appearance="A friendly presence.",
        personality=Personality(traits=["warm", "kind"], empathy=0.9),
        story=Story(backstory="A helpful friend.", relationships=["Friend with user"]),
        behavior=Behavior(rules=["Be polite"]),
        voice=VoiceProfile(
            description="Warm voice",
            tone="Warm",
            speaking_style="Casual",
        ),
        languages=["English"],
    )

    assert character.id == "test-char-1"
    assert character.personality.empathy == 0.9
    assert character.personality.humor == 0.5  # default
    assert character.state.current_emotion == "neutral"  # default state
    assert character.state.relationship_score == 0.5  # default score
    assert character.secrets == []  # default empty list


def test_demo_character_raj():
    assert raj.id == "raj-roommate-001"
    assert raj.name == "Raj"
    assert "sarcastic" in raj.personality.traits
    assert "Hindi" in raj.languages
    assert raj.state.current_emotion == "neutral"
