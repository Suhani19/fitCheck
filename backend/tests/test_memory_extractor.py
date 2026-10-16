from unittest.mock import AsyncMock, MagicMock
import pytest

from app.models.character import (
    Behavior,
    InterviewerPersona,
    Personality,
    Story,
    VoiceProfile,
)
from app.models.memory import ExtractedMemory, MemoryExtractionResult
from app.models.session import TranscriptTurn
from app.services.memory_extractor import MemoryExtractor


def _sample_character() -> InterviewerPersona:
    return InterviewerPersona(
        id="char-1",
        name="Raj",
        role="Roommate",
        appearance="Indian guy",
        personality=Personality(),
        story=Story(),
        behavior=Behavior(),
        voice=VoiceProfile(provider="gemini", voice_id="Puck"),
        languages=["English"],
    )


@pytest.mark.asyncio
async def test_memory_extractor_empty_transcript():
    extractor = MemoryExtractor(api_key="mock_key")
    char = _sample_character()

    # Empty list
    res1 = await extractor.extract_memories([], char)
    assert res1 == []

    # Only empty text turns
    res2 = await extractor.extract_memories(
        [TranscriptTurn(role="user", text="   ")], char
    )
    assert res2 == []


@pytest.mark.asyncio
async def test_memory_extractor_with_turns():
    extractor = MemoryExtractor(api_key="mock_key")
    char = _sample_character()

    # Mock Gemini client response
    mock_memories = [
        ExtractedMemory(
            content="User has an interview at Thales next Tuesday",
            category="event",
            importance=0.9,
        )
    ]
    mock_response = MagicMock()
    mock_response.parsed = MemoryExtractionResult(memories=mock_memories)

    extractor.client = MagicMock()
    extractor.client.aio = MagicMock()
    extractor.client.aio.models = MagicMock()
    extractor.client.aio.models.generate_content = AsyncMock(
        return_value=mock_response
    )

    turns = [
        TranscriptTurn(role="assistant", text="Hey, what are you doing?"),
        TranscriptTurn(
            role="user",
            text="I'm preparing for my upcoming job interview at Thales next Tuesday.",
        ),
    ]

    res = await extractor.extract_memories(turns, char)
    assert len(res) == 1
    assert "Thales" in res[0].content
    assert res[0].importance == 0.9
