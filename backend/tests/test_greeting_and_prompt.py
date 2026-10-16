from app.agents.runtime_prompt import (
    build_character_system_prompt,
    build_contextual_greeting,
)
from app.models.character import (
    Behavior,
    InterviewerPersona,
    Personality,
    Story,
    VoiceProfile,
)
from app.models.demo_character import raj
from app.models.memory import CharacterMemory
from app.models.session import CharacterRelationship


def _create_character(name: str = "Elena", traits: list[str] = None) -> InterviewerPersona:
    return InterviewerPersona(
        id="char-elena-001",
        name=name,
        role="Traveler",
        appearance="A friendly traveler",
        personality=Personality(traits=traits or ["calm", "curious"]),
        story=Story(backstory="Travels around the world."),
        behavior=Behavior(rules=["Ask about local food"]),
        voice=VoiceProfile(
            provider="gemini",
            voice_id="Aoede",
            description="Warm feminine voice",
        ),
        languages=["English"],
    )


def test_greeting_first_meeting():
    char = _create_character()
    rel = CharacterRelationship(
        character_id=char.id,
        user_id="u1",
        total_sessions=0,
    )
    greeting = build_contextual_greeting(char, relationship=rel)
    assert "Elena" in greeting
    # Should be an introduction
    assert "meet you" in greeting.lower()


def test_greeting_returning_user():
    char = _create_character()
    rel = CharacterRelationship(
        character_id=char.id,
        user_id="u1",
        total_sessions=3,
    )
    greeting = build_contextual_greeting(char, relationship=rel)
    # Should welcome back
    assert "again" in greeting.lower()


def test_greeting_raj_returning():
    rel = CharacterRelationship(
        character_id=raj.id,
        user_id="u1",
        total_sessions=2,
    )
    greeting = build_contextual_greeting(raj, relationship=rel)
    assert "back" in greeting.lower()


def test_prompt_includes_relationship_and_memories():
    char = _create_character()
    rel = CharacterRelationship(
        character_id=char.id,
        user_id="u1",
        total_sessions=4,
        relationship_score=0.72,
    )
    memories = [
        CharacterMemory(
            id="m1",
            character_id=char.id,
            user_id="u1",
            content="User lives in Paris and loves bakeries",
            category="preference",
            importance=0.9,
        ),
        CharacterMemory(
            id="m2",
            character_id=char.id,
            user_id="u1",
            content="User is interviewing at Thales next week",
            category="event",
            importance=0.95,
        ),
    ]

    prompt = build_character_system_prompt(char, relationship=rel, memories=memories)

    assert "Total conversations completed together: 4" in prompt
    assert "Relationship score (0.0 to 1.0): 0.72" in prompt
    assert "DO NOT introduce yourself as a stranger" in prompt
    assert "User lives in Paris and loves bakeries" in prompt
    assert "User is interviewing at Thales next week" in prompt
