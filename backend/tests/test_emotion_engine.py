import pytest
from app.models.character import (
    Behavior,
    CharacterState,
    InterviewerPersona,
    Personality,
    Story,
    VoiceProfile,
)
from app.models.emotion import BaseEmotion, EmotionState
from app.models.session import CharacterRelationship
from app.services.emotion_engine import (
    EmotionEngine,
    detect_language,
    is_language_supported_by_character,
)
from app.agents.runtime_prompt import build_character_system_prompt


def _make_char(
    id: str = "test-char-1",
    name: str = "Test Char",
    role: str = "Barber",
    traits: list[str] | None = None,
    humor: float = 0.5,
    patience: float = 0.5,
    emotional_volatility: float = 0.5,
    empathy: float = 0.5,
    languages: list[str] | None = None,
    current_emotion: str = "neutral",
    emotional_intensity: float = 0.0,
) -> InterviewerPersona:
    return InterviewerPersona(
        id=id,
        name=name,
        role=role,
        appearance="Ordinary person",
        personality=Personality(
            traits=traits or ["friendly"],
            humor=humor,
            patience=patience,
            emotional_volatility=emotional_volatility,
            empathy=empathy,
        ),
        story=Story(backstory="Barber in local town", relationships=[], experiences=[], goals=[]),
        behavior=Behavior(rules=[], likes=["styling hair", "chai"], dislikes=["rudeness"], triggers=[], boundaries=[]),
        secrets=[],
        voice=VoiceProfile(provider="gemini", voice_id="Aoede"),
        languages=languages or ["English", "Hindi"],
        state=CharacterState(current_emotion=current_emotion, emotional_intensity=emotional_intensity),
    )


def test_emotion_engine_detection_all_base_emotions():
    engine = EmotionEngine()
    char = _make_char()

    # 1. Excited
    res_excited = engine.process_turn(
        character=char,
        user_text="I finally got the job! I'm so excited!",
        character_response="Congratulations!",
    )
    assert res_excited.emotion == BaseEmotion.EXCITED.value
    assert res_excited.intensity >= 0.70

    # 2. Amused
    res_amused = engine.process_turn(
        character=char,
        user_text="Haha that joke was hilarious, I'm cracking up!",
        character_response="I know, right?",
    )
    assert res_amused.emotion == BaseEmotion.AMUSED.value
    assert res_amused.intensity >= 0.60

    # 3. Sad
    res_sad = engine.process_turn(
        character=char,
        user_text="I lost my dog yesterday and I'm heartbroken and crying.",
        character_response="I'm so sorry to hear that.",
    )
    assert res_sad.emotion == BaseEmotion.SAD.value
    assert res_sad.intensity >= 0.65

    # 4. Defensive
    res_defensive = engine.process_turn(
        character=char,
        user_text="Shut up you stupid idiot, you are completely useless.",
        character_response="Excuse me?",
    )
    assert res_defensive.emotion == BaseEmotion.DEFENSIVE.value
    assert res_defensive.intensity >= 0.70

    # 5. Happy
    res_happy = engine.process_turn(
        character=char,
        user_text="Thank you so much, this is wonderful and I appreciate it.",
        character_response="You're very welcome!",
    )
    assert res_happy.emotion == BaseEmotion.HAPPY.value
    assert res_happy.intensity >= 0.55

    # 6. Neutral
    res_neutral = engine.process_turn(
        character=char,
        user_text="What time does the store open on Tuesdays?",
        character_response="Around 9 AM.",
    )
    assert res_neutral.emotion == BaseEmotion.NEUTRAL.value


def test_emotion_persistence_and_decay():
    engine = EmotionEngine()
    char = _make_char()

    # Start with high excitement
    state = EmotionState(emotion="excited", intensity=0.85)

    # Turn 1: Unreinforced neutral statement
    state = engine.process_turn(
        character=char,
        user_text="What did you have for lunch?",
        character_response="Just a sandwich.",
        current_state=state,
    )
    assert state.emotion == "excited"
    assert state.intensity < 0.85
    assert "decay_excited" in state.reason

    # Turn 2: Another neutral statement
    state = engine.process_turn(
        character=char,
        user_text="Did it rain outside today?",
        character_response="No, quite sunny.",
        current_state=state,
    )
    assert state.emotion == "excited"
    assert state.intensity < 0.68

    # Turn 3: Another neutral statement
    state = engine.process_turn(
        character=char,
        user_text="Where is the train station?",
        character_response="Down the street.",
        current_state=state,
    )
    assert state.emotion == "excited"
    assert state.intensity < 0.50

    # Turn 4: Settles back to neutral after continued lack of reinforcement
    state = engine.process_turn(
        character=char,
        user_text="Okay, got it.",
        character_response="Cool.",
        current_state=state,
    )
    assert state.emotion == "neutral"
    assert state.reason == "settled_to_neutral"


def test_emotion_reinforcement_momentum():
    engine = EmotionEngine()
    char = _make_char()

    state = EmotionState(emotion="excited", intensity=0.65)

    # Reinforcing positive event
    state = engine.process_turn(
        character=char,
        user_text="And we also won the championship game today! Huge news!",
        character_response="No way! That is incredible!",
        current_state=state,
    )
    assert state.emotion == "excited"
    assert state.intensity > 0.65
    assert "reinforced" in state.reason


def test_personality_affects_emotion():
    engine = EmotionEngine()

    # Sarcastic / witty character gets amused with higher intensity
    witty_char = _make_char(
        traits=["sarcastic", "witty", "playful"],
        humor=0.85,
    )
    res_witty = engine.process_turn(
        character=witty_char,
        user_text="Haha that prank was ridiculous!",
    )

    # Serious / sober character
    serious_char = _make_char(
        traits=["serious", "solemn"],
        humor=0.2,
    )
    res_serious = engine.process_turn(
        character=serious_char,
        user_text="Haha that prank was ridiculous!",
    )

    assert res_witty.intensity > res_serious.intensity

    # Volatile character gets defensive with higher intensity
    volatile_char = _make_char(
        traits=["impatient", "irritable"],
        emotional_volatility=0.85,
        patience=0.2,
    )
    res_volatile = engine.process_turn(
        character=volatile_char,
        user_text="You're wrong and this is rubbish!",
    )
    assert res_volatile.intensity >= 0.85


def test_relationship_affects_emotion():
    engine = EmotionEngine()
    char = _make_char()

    # High tension relationship biases toward defensiveness
    tense_rel = CharacterRelationship(
        character_id=char.id,
        user_id="user1",
        tension=65,
    )
    res_tense = engine.process_turn(
        character=char,
        user_text="Stop talking, you're wrong.",
        relationship=tense_rel,
    )
    assert res_tense.emotion == "defensive"
    assert res_tense.intensity >= 0.85

    # High familiarity & affection softens defensiveness
    friendly_rel = CharacterRelationship(
        character_id=char.id,
        user_id="user1",
        familiarity=75,
        affection=70,
        tension=0,
    )
    res_friendly = engine.process_turn(
        character=char,
        user_text="You're wrong about that movie.",
        relationship=friendly_rel,
    )
    # Even if conflict keyword triggered, intensity is noticeably softer
    assert res_friendly.intensity < res_tense.intensity


def test_language_detection_and_character_boundaries():
    # 1. Detection of various languages
    assert detect_language("Hello, how are you today?") == "english"
    assert detect_language("Haan yaar, aaj kaafi tired hoon but kaam baki hai.") == "hinglish"
    assert detect_language("नमस्ते, आप कैसे हैं?") == "hindi"
    assert detect_language("Bonjour! Comment vous vous appelez?") == "french"
    assert detect_language("Hola amigo, como estas?") == "spanish"

    # 2. Strict character language boundary check
    # French character who only knows English and French
    french_char = _make_char(name="Pierre", languages=["English", "French"])

    assert is_language_supported_by_character(french_char, "english") is True
    assert is_language_supported_by_character(french_char, "french") is True
    # Must NOT support Hindi or Hinglish or Spanish
    assert is_language_supported_by_character(french_char, "hindi") is False
    assert is_language_supported_by_character(french_char, "hinglish") is False
    assert is_language_supported_by_character(french_char, "spanish") is False

    # Indian character who knows English and Hindi
    raj_char = _make_char(name="Raj", languages=["English", "Hindi"])
    assert is_language_supported_by_character(raj_char, "english") is True
    assert is_language_supported_by_character(raj_char, "hindi") is True
    assert is_language_supported_by_character(raj_char, "hinglish") is True
    assert is_language_supported_by_character(raj_char, "french") is False


def test_prompt_includes_emotion_and_strict_language_boundaries():
    char = _make_char(
        name="Pierre",
        role="Chef",
        languages=["English", "French"],
        current_emotion="excited",
        emotional_intensity=0.85,
    )
    prompt = build_character_system_prompt(char)

    # 1. Emotion guidance in prompt
    assert "EXCITED" in prompt
    assert "85%" in prompt
    assert "elevated energy" in prompt

    # 2. Strict language boundary in prompt
    assert "CRITICAL STRICT LANGUAGE BOUNDARY" in prompt
    assert "You ONLY speak and understand the languages explicitly listed above: English, French" in prompt
    assert "YOU DO NOT KNOW OR SPEAK THAT LANGUAGE" in prompt

    # 3. Anti-assistant & Knowledge boundaries
    assert "Chef" in prompt
    assert "DISTINGUISH MODEL KNOWLEDGE VS. CHARACTER KNOWLEDGE" in prompt


def test_emotion_engine_fallback_on_error():
    engine = EmotionEngine()
    # Passing invalid non-object to simulate internal failure
    fallback = engine.process_turn(
        character=None,  # type: ignore
        user_text="hello",
        current_state=EmotionState(emotion="happy", intensity=0.5),
    )
    # Should fallback gracefully without raising
    assert fallback.emotion in [BaseEmotion.HAPPY.value, BaseEmotion.NEUTRAL.value]
