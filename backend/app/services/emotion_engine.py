import logging
import re
from datetime import datetime, timezone
from typing import Any

from app.models.character import InterviewerPersona
from app.models.emotion import BaseEmotion, EmotionState
from app.models.session import CharacterRelationship

logger = logging.getLogger(__name__)

# Trigger keyword patterns for lightweight, zero-latency contextual emotion detection
_POSITIVE_EXCITEMENT_PATTERNS = [
    r"\b(got the job|promoted|promotion|won|celebrate|celebrating|huge news|finally|passed|accepted|congratulations|we did it|dream come true|nailed it|thrilled|super excited)\b",
]

_POSITIVE_HAPPY_PATTERNS = [
    r"\b(happy|glad|wonderful|good news|love this|great day|awesome|feeling good|blessed|thank you so much|proud of you|appreciate)\b",
]

_HUMOR_AMUSED_PATTERNS = [
    r"\b(haha|hahaha|lol|lmao|funny|hilarious|cracking up|joke|prank|ridiculous|rofl|bizarre|nonsense|you crack me up)\b",
]

_SAD_PATTERNS = [
    r"\b(sad|crying|depressed|grief|lost my|passed away|died|broken|funeral|heartbroken|awful|miserable|lonely|feeling down|hopeless|failed)\b",
]

_HOSTILE_DEFENSIVE_PATTERNS = [
    r"\b(shut up|stupid|idiot|hate you|liar|useless|annoying|leave me alone|fuck|dumb|terrible|worthless|stop talking|get lost|you're wrong|full of shit|rubbish)\b",
]

# Language detection signatures
_HINDI_SCRIPT_PATTERN = re.compile(r"[\u0900-\u097F]")
_HINGLISH_MARKERS = [
    "haan", "nahi", "nahin", "kya", "kyu", "kyun", "kaise", "bhai", "yaar", "accha",
    "achha", "theek", "thik", "bol", "bolo", "karo", "karenge", "raha", "rahe", "hai",
    "hain", "hota", "hoti", "waise", "aaj", "kal", "abhi", "sahi", "matlab", "arrey",
    "arey", "batao", "chal", "chalo", "sab", "kuch", "aisa", "aise", "meri", "mera"
]

_FRENCH_MARKERS = ["bonjour", "salut", "merci", "oui", "non", "pourquoi", "comment", "voila", "je", "tu", "vous", "avec"]
_SPANISH_MARKERS = ["hola", "gracias", "amigo", "por", "favor", "como", "esta", "bueno", "si", "no"]


def detect_language(text: str) -> str:
    """Detects primary language of text among English, Hindi, Hinglish, French, Spanish."""
    if not text or not text.strip():
        return "english"

    # 1. Devanagari script indicates Hindi
    if _HINDI_SCRIPT_PATTERN.search(text):
        return "hindi"

    words = re.findall(r"\b[a-zA-Z]+\b", text.lower())
    if not words:
        return "english"

    # Count language markers
    hinglish_matches = sum(1 for w in words if w in _HINGLISH_MARKERS)
    french_matches = sum(1 for w in words if w in _FRENCH_MARKERS)
    spanish_matches = sum(1 for w in words if w in _SPANISH_MARKERS)

    total_words = len(words)

    if hinglish_matches > 0 and (hinglish_matches >= 2 or hinglish_matches / total_words >= 0.15):
        return "hinglish"
    if french_matches > 0 and (french_matches >= 2 or french_matches / total_words >= 0.20):
        return "french"
    if spanish_matches > 0 and (spanish_matches >= 2 or spanish_matches / total_words >= 0.20):
        return "spanish"

    return "english"


def is_language_supported_by_character(character: InterviewerPersona, language: str) -> bool:
    """Checks whether the character is configured to speak the detected language."""
    known_langs = [l.lower().strip() for l in character.languages]
    lang_lower = language.lower().strip()

    # Hinglish is supported if character speaks Hindi or English
    if lang_lower == "hinglish":
        return any("hindi" in l or "hinglish" in l for l in known_langs)

    return any(lang_lower in l or l in lang_lower for l in known_langs)


class EmotionEngine:
    """Contextual emotion engine with persistence, decay, personality, and relationship bias."""

    DECAY_RATE = 0.18
    MIN_INTENSITY_THRESHOLD = 0.25
    DEFAULT_NEUTRAL_INTENSITY = 0.35

    def __init__(self) -> None:
        pass

    def process_turn(
        self,
        character: InterviewerPersona,
        user_text: str,
        character_response: str = "",
        current_state: EmotionState | None = None,
        relationship: CharacterRelationship | None = None,
    ) -> EmotionState:
        """Processes a conversation turn and returns updated EmotionState with continuity."""
        try:
            prev_state = current_state or EmotionState(
                emotion=character.state.current_emotion or BaseEmotion.NEUTRAL.value,
                intensity=character.state.emotional_intensity if character.state.emotional_intensity > 0 else self.DEFAULT_NEUTRAL_INTENSITY,
            )

            # Detect language for observability
            user_lang = detect_language(user_text)
            resp_lang = detect_language(character_response) if character_response else user_lang
            print(f"[LANGUAGE] detected={user_lang} response={resp_lang}", flush=True)
            logger.info("[LANGUAGE] detected=%s response=%s", user_lang, resp_lang)

            # Analyze emotional cues
            detected_raw_emotion, raw_intensity, reason = self._detect_raw_emotion(
                user_text=user_text,
                character_response=character_response,
            )

            # Apply personality and relationship modifiers
            final_emotion, final_intensity, final_reason = self._apply_context_and_decay(
                character=character,
                relationship=relationship,
                prev_state=prev_state,
                detected_emotion=detected_raw_emotion,
                raw_intensity=raw_intensity,
                reason=reason,
            )

            # Diagnostic logging (M6.15)
            trans_str = f"{prev_state.emotion}->{final_emotion}"
            log_line = (
                f"[EMOTION] previous={prev_state.emotion} "
                f"detected={final_emotion} "
                f"intensity={final_intensity:.2f} "
                f"reason={final_reason} "
                f"transition={trans_str}"
            )
            print(log_line, flush=True)
            logger.info(log_line)

            return EmotionState(
                emotion=final_emotion,
                intensity=round(final_intensity, 2),
                updated_at=datetime.now(timezone.utc).isoformat(),
                reason=final_reason,
            )

        except Exception as exc:
            logger.error("[EMOTION] Detection failed, falling back to previous state: %s", exc)
            return current_state or EmotionState()

    def _detect_raw_emotion(
        self,
        user_text: str,
        character_response: str,
    ) -> tuple[str, float, str]:
        """Classifies the conversational exchange into a base emotion candidate."""
        combined = f"{user_text} {character_response}".lower()

        # 1. Hostile / Insults / Tension -> Defensive
        for pat in _HOSTILE_DEFENSIVE_PATTERNS:
            if re.search(pat, combined):
                return BaseEmotion.DEFENSIVE.value, 0.80, "hostile_or_conflict_interaction"

        # 2. Sadness / Grief / Failure -> Sad
        for pat in _SAD_PATTERNS:
            if re.search(pat, combined):
                return BaseEmotion.SAD.value, 0.75, "sad_situation_or_loss"

        # 3. Exciting news / Big win -> Excited
        for pat in _POSITIVE_EXCITEMENT_PATTERNS:
            if re.search(pat, combined):
                return BaseEmotion.EXCITED.value, 0.85, "positive_user_achievement"

        # 4. Humor / Joke / Sarcasm -> Amused
        for pat in _HUMOR_AMUSED_PATTERNS:
            if re.search(pat, combined):
                return BaseEmotion.AMUSED.value, 0.70, "funny_situation_or_banter"

        # 5. General positive / Warmth -> Happy
        for pat in _POSITIVE_HAPPY_PATTERNS:
            if re.search(pat, combined):
                return BaseEmotion.HAPPY.value, 0.65, "warm_positive_interaction"

        # 6. Default neutral / unreinforced
        return BaseEmotion.NEUTRAL.value, self.DEFAULT_NEUTRAL_INTENSITY, "normal_conversation"

    def _apply_context_and_decay(
        self,
        character: InterviewerPersona,
        relationship: CharacterRelationship | None,
        prev_state: EmotionState,
        detected_emotion: str,
        raw_intensity: float,
        reason: str,
    ) -> tuple[str, float, str]:
        """Calculates emotional momentum, personality modulation, relationship bias, and decay."""
        rel_tension = relationship.tension if relationship else 0
        rel_familiarity = relationship.familiarity if relationship else 10
        rel_affection = relationship.affection if relationship else 15

        personality = character.personality
        traits_lower = [t.lower() for t in personality.traits]

        # Case 1: An active non-neutral event was detected
        if detected_emotion != BaseEmotion.NEUTRAL.value:
            intensity = raw_intensity

            # Personality modifiers
            if detected_emotion == BaseEmotion.AMUSED.value:
                if personality.humor >= 0.7 or any(t in traits_lower for t in ["sarcastic", "witty", "playful"]):
                    intensity = min(1.0, intensity + 0.12)
            elif detected_emotion == BaseEmotion.DEFENSIVE.value:
                if personality.patience < 0.4 or personality.emotional_volatility >= 0.7 or rel_tension >= 40:
                    intensity = min(1.0, intensity + 0.15)
                # High familiarity and affection slightly soften defensiveness
                if rel_familiarity >= 60 and rel_affection >= 50:
                    intensity = max(0.40, intensity - 0.15)
            elif detected_emotion in (BaseEmotion.EXCITED.value, BaseEmotion.HAPPY.value):
                if personality.empathy >= 0.7 or any(t in traits_lower for t in ["caring", "enthusiastic", "friendly"]):
                    intensity = min(1.0, intensity + 0.10)
                # Low familiarity dampens wild excitement
                if rel_familiarity < 25:
                    intensity = max(0.45, intensity - 0.10)
            elif detected_emotion == BaseEmotion.SAD.value:
                if personality.empathy >= 0.7 or any(t in traits_lower for t in ["caring", "thoughtful", "gentle"]):
                    intensity = min(1.0, intensity + 0.12)

            # Momentum: if same as previous emotion, reinforce intensity
            if detected_emotion == prev_state.emotion:
                intensity = min(1.0, prev_state.intensity + 0.15)
                reason = f"reinforced_{detected_emotion}"

            return detected_emotion, intensity, reason

        # Case 2: No non-neutral event detected in this turn -> EMOTION DECAY (M6.3)
        if prev_state.emotion != BaseEmotion.NEUTRAL.value:
            decayed_intensity = prev_state.intensity - self.DECAY_RATE
            if decayed_intensity > self.MIN_INTENSITY_THRESHOLD:
                # Retain emotional continuity with lower intensity
                return prev_state.emotion, decayed_intensity, f"decay_{prev_state.emotion}"
            else:
                # Settles back to neutral
                return BaseEmotion.NEUTRAL.value, self.DEFAULT_NEUTRAL_INTENSITY, "settled_to_neutral"

        # Case 3: Remains neutral
        return BaseEmotion.NEUTRAL.value, self.DEFAULT_NEUTRAL_INTENSITY, "calm_steady_neutral"
