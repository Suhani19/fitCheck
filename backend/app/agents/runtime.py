import logging
import os

from agora_agent.agentkit.agent import Agent
from agora_agent.agentkit.vendors import GeminiLive
from agora_agent.types.mllm_turn_detection import MllmTurnDetection
from agora_agent.types.mllm_turn_detection_agora_vad_config import (
    MllmTurnDetectionAgoraVadConfig,
)

from app.agents.runtime_prompt import (
    build_character_system_prompt,
    build_contextual_greeting,
)
from app.models.character import InterviewerPersona
from app.repositories.base import (
    CharacterRepository,
    MemoryRepository,
    RelationshipRepository,
)
from app.repositories.sqlite import (
    SQLiteCharacterRepository,
    SQLiteMemoryRepository,
    SQLiteRelationshipRepository,
)
from app.services.agora import AgoraService
from app.services.voice_selector import VoiceSelector

logger = logging.getLogger(__name__)


class RuntimeAgent:
    """Runs a FitCheck interviewer persona through Agora Conversational AI."""

    def __init__(
        self,
        character_repo: CharacterRepository | None = None,
        relationship_repo: RelationshipRepository | None = None,
        memory_repo: MemoryRepository | None = None,
    ) -> None:
        self.agora = AgoraService()
        self.character_repo = character_repo or SQLiteCharacterRepository()
        self.relationship_repo = relationship_repo or SQLiteRelationshipRepository()
        self.memory_repo = memory_repo or SQLiteMemoryRepository()

        gemini_api_key = os.getenv("GEMINI_API_KEY")

        if not gemini_api_key:
            raise RuntimeError("GEMINI_API_KEY is not configured.")

        self.gemini_api_key = gemini_api_key

    def start(
        self,
        character: InterviewerPersona,
        channel: str,
        remote_uid: str = "1001",
        user_id: str = "default_user",
    ) -> str:
        # 1. Deterministic and persistent voice selection
        voice_id = VoiceSelector.get_or_assign_voice(
            character, repository=self.character_repo
        )
        logger.info(
            "[VOICE] Starting character '%s' (%s) with voice_id: '%s'",
            character.name,
            character.id,
            voice_id,
        )

        # 2. Retrieve relationship context & top persistent memories
        relationship = self.relationship_repo.get_relationship(
            character.id, user_id=user_id
        )
        memories = self.memory_repo.get_memories(
            character.id, user_id=user_id, limit=8
        )
        print(f"[MEMORY] retrieved={len(memories)}", flush=True)
        mem_msg = f"[MEMORY] retrieved for next session: {len(memories)} memories"
        print(mem_msg, flush=True)
        logger.info(mem_msg)
        for m in memories:
            logger.info("  - [%s] %s", m.category, m.content)

        # 3. Contextual prompt & greeting
        system_prompt = build_character_system_prompt(
            character=character,
            relationship=relationship,
            memories=memories,
        )
        inject_msg = f"[MEMORY] injecting {len(memories)} memories into runtime prompt"
        print(inject_msg, flush=True)
        logger.info(inject_msg)

        greeting = build_contextual_greeting(
            character=character,
            relationship=relationship,
            memories=memories,
        )

        turn_detection = MllmTurnDetection(
            mode="agora_vad",
            agora_vad_config=MllmTurnDetectionAgoraVadConfig(
                interrupt_duration_ms=160,
                prefix_padding_ms=800,
                silence_duration_ms=640,
                threshold=0.5,
            ),
        )

        logger.info(
            "[MEMORY] final prompt context for '%s' (sessions=%d):\n%s",
            character.name,
            relationship.total_sessions,
            system_prompt,
        )
        logger.info(
            "RuntimeAgent starting session for character '%s' (voice='%s', sessions=%d, greeting='%s') in channel '%s'",
            character.name,
            voice_id,
            relationship.total_sessions,
            greeting,
            channel,
        )

        gemini_live = GeminiLive(
            api_key=self.gemini_api_key,
            model="models/gemini-3.8-live",
            instructions=system_prompt,
            voice=voice_id,
            language_codes=["en-US"],
            affective_dialog=False,
            proactive_audio=False,
            transcribe_agent=True,
            transcribe_user=True,
            greeting_message=greeting,
            input_modalities=["audio"],
            output_modalities=["audio"],
            turn_detection=turn_detection,
        )

        agent = (
            Agent(
                self.agora.client,
                greeting=greeting,
            )
            .with_mllm(gemini_live)
        )

        session = agent.create_session(
            channel=channel,
            agent_uid="0",
            remote_uids=[remote_uid],
            name=f"fitcheck-{character.id}-{channel}",
            idle_timeout=120,
            debug=True,
        )

        return session.start()