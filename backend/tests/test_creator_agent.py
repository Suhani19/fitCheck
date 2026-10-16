from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from app.agents.creator import CreatorAgent
from app.models.character import (
    Behavior,
    InterviewerPersona,
    Personality,
    Story,
    VoiceProfile,
)


@pytest.mark.asyncio
async def test_creator_agent_enforces_unique_slug_id():
    mock_character = InterviewerPersona(
        id="arbitrary_id_from_model",
        name="Pierre Dubois",
        role="French Chef",
        appearance="Chef coat with flour on hands.",
        personality=Personality(traits=["cheerful", "passionate"]),
        story=Story(backstory="Bakes in Paris."),
        behavior=Behavior(rules=["Bake with love"]),
        voice=VoiceProfile(
            description="Warm French accent",
            tone="Warm",
            speaking_style="Animated",
        ),
        languages=["English", "French"],
    )

    with patch("app.agents.creator.genai.Client") as mock_client_cls:
        mock_client = MagicMock()
        mock_response = MagicMock()
        mock_response.parsed = mock_character
        mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)
        mock_client_cls.return_value = mock_client

        agent = CreatorAgent()
        result = await agent.create_character("Create a French chef named Pierre Dubois.")

        assert result.name == "Pierre Dubois"
        assert result.id.startswith("pierre-dubois-")
        assert len(result.id) > len("pierre-dubois-")
        # Ensure model's original ID was replaced with collision-free slug
        assert result.id != "arbitrary_id_from_model"


@pytest.mark.asyncio
async def test_creator_agent_multilingual_samples():
    """Verify CreatorAgent works across English, Hindi, and Hinglish sample descriptions."""
    samples = [
        # English
        ("English", "A cheerful French chef named Pierre who loves baking pastries."),
        # Hindi
        ("Hindi", "Ek dadi maa ka character banao jinka naam Kamla hai jo pyaar se khana banati hain."),
        # Hinglish
        ("Hinglish", "I want a tech lead named Rohan who is super chill, speaks Hinglish, and helps debug."),
    ]

    for lang, description in samples:
        mock_char = InterviewerPersona(
            id="temp-id",
            name=f"Char_{lang}",
            role="Companion",
            appearance="Friendly persona.",
            personality=Personality(traits=["helpful"]),
            story=Story(backstory=f"Speaks {lang} naturally."),
            behavior=Behavior(rules=["Be friendly"]),
            voice=VoiceProfile(description="Natural tone", tone="Warm", speaking_style="Casual"),
            languages=["English", lang],
        )

        with patch("app.agents.creator.genai.Client") as mock_client_cls:
            mock_client = MagicMock()
            mock_response = MagicMock()
            mock_response.parsed = mock_char
            mock_client.aio.models.generate_content = AsyncMock(return_value=mock_response)
            mock_client_cls.return_value = mock_client

            agent = CreatorAgent()
            result = await agent.create_character(description)
            assert result.id.startswith(f"char-{lang.lower()}-")
