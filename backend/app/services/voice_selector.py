import logging
from app.models.character import InterviewerPersona
from app.repositories.base import CharacterRepository

logger = logging.getLogger(__name__)

GEMINI_FEMALE_VOICES = ["Aoede", "Kore"]
GEMINI_MALE_VOICES = ["Puck", "Fenrir", "Charon"]

FEMALE_KEYWORDS = {
    "female",
    "woman",
    "women",
    "girl",
    "girls",
    "lady",
    "ladies",
    "she",
    "her",
    "hers",
    "herself",
    "mother",
    "sister",
    "daughter",
    "actress",
    "waitress",
    "queen",
    "princess",
    "mrs",
    "ms",
    "miss",
    "aunt",
    "feminine",
    "wife",
    "mom",
    "grandmother",
    "grandma",
}

MALE_KEYWORDS = {
    "male",
    "man",
    "men",
    "boy",
    "boys",
    "guy",
    "guys",
    "he",
    "his",
    "him",
    "himself",
    "father",
    "brother",
    "son",
    "actor",
    "waiter",
    "king",
    "prince",
    "mr",
    "uncle",
    "masculine",
    "husband",
    "dad",
    "grandfather",
    "grandpa",
}

FEMALE_NAMES = {
    "maya",
    "priya",
    "ananya",
    "aanya",
    "neha",
    "pooja",
    "sarah",
    "elena",
    "aarti",
    "aisha",
    "anjali",
    "radha",
    "shreya",
    "diya",
    "ria",
    "kavita",
    "sunita",
    "meera",
    "sophia",
    "emma",
}

MALE_NAMES = {
    "raj",
    "rohan",
    "peter",
    "rahul",
    "amit",
    "vikram",
    "arjun",
    "karan",
    "alex",
    "john",
    "david",
}


class VoiceSelector:
    """Selects and persists a deterministic voice identity for a character."""

    @staticmethod
    def get_or_assign_voice(
        character: InterviewerPersona,
        repository: CharacterRepository | None = None,
    ) -> str:
        """Returns the character's voice_id.

        If already assigned, returns it immediately. If not assigned, determines
        a voice based on character metadata, updates the character, and persists
        it to repository if provided.
        """
        if character.voice.voice_id:
            return character.voice.voice_id

        selected_voice = VoiceSelector.determine_voice(character)
        character.voice.voice_id = selected_voice
        character.voice.provider = "gemini"

        if repository is not None:
            try:
                repository.update(character)
                logger.info(
                    "Persisted voice_id '%s' for character '%s' (%s)",
                    selected_voice,
                    character.name,
                    character.id,
                )
            except Exception as e:
                logger.warning(
                    "Failed to persist voice_id to repository for character %s: %s",
                    character.id,
                    e,
                )

        return selected_voice

    @staticmethod
    def determine_voice(character: InterviewerPersona) -> str:
        """Determines the best voice identifier based on character attributes."""
        # Combine comprehensive text signals
        signals = [
            character.name.lower(),
            character.role.lower(),
            character.appearance.lower(),
            character.story.backstory.lower(),
            " ".join(character.story.relationships).lower(),
            " ".join(character.story.goals).lower(),
            character.voice.description.lower(),
            character.voice.speaking_style.lower(),
            character.voice.tone.lower(),
            " ".join(character.personality.traits).lower(),
            " ".join(character.secrets).lower(),
        ]
        combined = " ".join(signals)

        # Tokenize words
        words = set(
            combined.replace(".", " ")
            .replace(",", " ")
            .replace("-", " ")
            .replace("'", " ")
            .replace("\"", " ")
            .split()
        )

        female_score = len(words.intersection(FEMALE_KEYWORDS))
        male_score = len(words.intersection(MALE_KEYWORDS))

        name_lower = character.name.lower().strip()
        if any(fn == name_lower or fn in name_lower.split() for fn in FEMALE_NAMES):
            female_score += 5
        elif any(mn == name_lower or mn in name_lower.split() for mn in MALE_NAMES):
            male_score += 5

        if female_score > male_score:
            return "Aoede"
        elif male_score > female_score:
            return "Puck"

        # Deterministic fallback based on character id hash
        val = sum(ord(c) for c in character.id)
        if val % 2 == 0:
            return "Puck"
        return "Aoede"
