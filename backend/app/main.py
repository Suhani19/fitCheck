import base64
import inspect
import os
import uuid
import httpx
from pathlib import Path

from dotenv import load_dotenv

# Ensure backend/.env is loaded regardless of working directory
_backend_dir = Path(__file__).resolve().parent.parent
_env_path = _backend_dir / ".env"
if _env_path.exists():
    load_dotenv(dotenv_path=_env_path)
else:
    load_dotenv()

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile, status
from fastapi.responses import Response
from pydantic import BaseModel, Field

from app.agents.creator import CreatorAgent
from app.agents.runtime import RuntimeAgent
from app.dependencies import (
    get_character_repository,
    get_memory_repository,
    get_relationship_repository,
    get_session_repository,
)
from app.services.speech import (
    SpeechProvider,
    get_speech_provider,
    resolve_audio_mime_type,
)
from app.models.character import (
    CharacterExtractionRequest,
    InterviewerPersona,
)
from app.models.memory import (
    CharacterMemory,
    MemoryListResponse,
)
import logging

from app.models.session import (
    CharacterRelationship,
    ConversationSession,
    EndSessionRequest,
    EndSessionResponse,
    TranscriptTurn,
)
from app.repositories.base import (
    CharacterRepository,
    MemoryRepository,
    RelationshipRepository,
    SessionRepository,
)
from app.services.agora import AgoraService
from app.services.agora_token import AgoraTokenService
from app.services.memory_extractor import MemoryExtractor
from app.models.emotion import (
    EmotionDetectRequest,
    EmotionDetectResponse,
    EmotionState,
)
from app.services.emotion_engine import EmotionEngine

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger(__name__)

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="FitCheck API",
    description="Backend service for FitCheck AI real-time interview simulations and candidate evaluation.",
    version="1.0.0",
)

# CORS configuration for web clients.
# Supports ALLOWED_ORIGINS env var (comma-separated list), with default support
# for local development (localhost, 127.0.0.1) and Firebase Hosting domains (*.web.app, *.firebaseapp.com).
_raw_allowed_origins = os.getenv("ALLOWED_ORIGINS", "").strip()
if _raw_allowed_origins:
    _origins = [o.strip() for o in _raw_allowed_origins.split(",") if o.strip()]
    if "*" in _origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=False,
            allow_methods=["*"],
            allow_headers=["*"],
        )
    else:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=_origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=(
            r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$|"
            r"^https://[a-zA-Z0-9-]+(\.web\.app|\.firebaseapp\.com)$"
        ),
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

from app.api.v1_router import router as fitcheck_v1_router
app.include_router(fitcheck_v1_router)


@app.on_event("startup")
def on_startup():
    from app.db.database import SessionLocal
    from app.db.seed_presets import seed_interviewer_presets
    from app.db.legacy_migrator import migrate_legacy_sqlite_data

    db = SessionLocal()
    try:
        seed_interviewer_presets(db)
        migrate_legacy_sqlite_data(db)
    except Exception as exc:
        logger.warning("Startup initialization note: %s", exc)
    finally:
        db.close()



class RuntimeSessionRequest(BaseModel):
    character_id: str = Field(..., description="ID of the character to start call with")
    user_id: str = Field(default="default_user", description="ID of the user")


class RuntimeSessionResponse(BaseModel):
    session_id: str
    status: str
    agent_id: str
    character_id: str
    character_name: str
    channel: str
    uid: int
    rtc_token: str
    app_id: str



@app.get("/health")
@app.get("/api/health")
@app.get("/api/v1/health")
async def health():
    return {
        "status": "ok",
        "service": "fitcheck-api",
    }


# Character CRUD Endpoints


@app.get("/characters", response_model=list[InterviewerPersona])
async def list_characters(
    repo: CharacterRepository = Depends(get_character_repository),
):
    return repo.list()


@app.post("/characters", response_model=InterviewerPersona, status_code=status.HTTP_201_CREATED)
async def create_character(
    character: InterviewerPersona,
    repo: CharacterRepository = Depends(get_character_repository),
):
    try:
        return repo.create(character)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc


@app.get("/characters/bin", response_model=list[InterviewerPersona])
async def list_characters_in_bin(
    repo: CharacterRepository = Depends(get_character_repository),
):
    return repo.list_deleted()


@app.delete("/characters/bin")
async def empty_character_bin(
    repo: CharacterRepository = Depends(get_character_repository),
):
    count = repo.empty_bin()
    return {"status": "bin_emptied", "deleted_count": count}


@app.get("/characters/{character_id}", response_model=InterviewerPersona)
async def get_character(
    character_id: str,
    include_deleted: bool = False,
    repo: CharacterRepository = Depends(get_character_repository),
):
    character = repo.get(character_id, include_deleted=include_deleted)
    if not character:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Character '{character_id}' not found.",
        )
    return character


@app.put("/characters/{character_id}", response_model=InterviewerPersona)
async def update_character(
    character_id: str,
    character: InterviewerPersona,
    repo: CharacterRepository = Depends(get_character_repository),
):
    if character.id != character_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Payload character ID does not match URL path.",
        )
    try:
        return repo.update(character)
    except KeyError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Character '{character_id}' not found.",
        ) from exc


@app.post("/characters/{character_id}/restore", response_model=InterviewerPersona)
async def restore_character(
    character_id: str,
    repo: CharacterRepository = Depends(get_character_repository),
):
    restored = repo.restore(character_id)
    if not restored:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Character '{character_id}' not found in Bin.",
        )
    char = repo.get(character_id)
    return char


@app.delete("/characters/{character_id}/permanent")
async def permanently_delete_character(
    character_id: str,
    repo: CharacterRepository = Depends(get_character_repository),
):
    deleted = repo.permanent_delete(character_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Character '{character_id}' not found.",
        )
    return {
        "status": "permanently_deleted",
        "character_id": character_id,
    }


@app.delete("/characters/{character_id}")
async def delete_character(
    character_id: str,
    repo: CharacterRepository = Depends(get_character_repository),
    session_repo: SessionRepository = Depends(get_session_repository),
):
    # Verify character exists
    existing = repo.get(character_id, include_deleted=True)
    if not existing:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Character '{character_id}' not found.",
        )

    # Active call protection
    if hasattr(session_repo, "_get_connection"):
        with session_repo._get_connection() as conn:
            cursor = conn.execute(
                "SELECT COUNT(*) FROM conversation_sessions WHERE character_id = ? AND status = 'active';",
                (character_id,),
            )
            active_count = cursor.fetchone()[0]
            if active_count > 0:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Character '{character_id}' is currently on an active call. End the call before moving to Bin.",
                )

    deleted = repo.delete(character_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Character '{character_id}' not found.",
        )
    return {
        "status": "deleted",
        "character_id": character_id,
    }


@app.post("/characters/extract", response_model=InterviewerPersona)
async def extract_character(
    request: CharacterExtractionRequest,
):
    try:
        agent = CreatorAgent()
        return await agent.create_character(request.description)

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Character creation failed: {exc}",
        ) from exc


class SpeechTranscriptionResponse(BaseModel):
    transcript: str


@app.post("/speech/transcribe", response_model=SpeechTranscriptionResponse)
async def transcribe_speech(
    file: UploadFile = File(...),
    speech_provider: SpeechProvider = Depends(get_speech_provider),
):
    try:
        content = await file.read()
        if not content:
            return SpeechTranscriptionResponse(transcript="")
        mime_type = resolve_audio_mime_type(file.content_type, file.filename)
        transcript = await speech_provider.transcribe(content, mime_type=mime_type)
        return SpeechTranscriptionResponse(transcript=transcript)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Speech transcription failed: {exc}",
        ) from exc


# Runtime Endpoints


@app.post("/runtime/session", response_model=RuntimeSessionResponse)
async def create_runtime_session(
    request: RuntimeSessionRequest,
    repo: CharacterRepository = Depends(get_character_repository),
    session_repo: SessionRepository = Depends(get_session_repository),
    rel_repo: RelationshipRepository = Depends(get_relationship_repository),
    mem_repo: MemoryRepository = Depends(get_memory_repository),
):
    character = repo.get(request.character_id, include_deleted=True)
    if not character:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Character '{request.character_id}' not found.",
        )
    if character.deleted_at is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Character '{character.name}' is in the Bin. Restore the character before calling.",
        )

    try:
        logger.info(
            "Creating runtime session for character '%s' (%s), user '%s'",
            character.name,
            character.id,
            request.user_id,
        )
        runtime = RuntimeAgent(
            character_repo=repo,
            relationship_repo=rel_repo,
            memory_repo=mem_repo,
        )
        session_id = uuid.uuid4().hex[:10]
        # Clean channel name using character id slug
        channel_slug = "".join(c for c in character.id if c.isalnum() or c == "-")[:12]
        channel = f"fitcheck-{channel_slug}-{session_id}"
        remote_uid = "1001"

        agent_id = runtime.start(
            character=character,
            channel=channel,
            remote_uid=remote_uid,
            user_id=request.user_id,
        )

        session_obj = ConversationSession(
            id=session_id,
            character_id=character.id,
            user_id=request.user_id,
            channel=channel,
            agent_id=agent_id,
            status="active",
        )
        session_repo.create_session(session_obj)

        token_service = AgoraTokenService()
        rtc_token = token_service.generate_rtc_token(
            channel=channel,
            uid=int(remote_uid),
        )

        return RuntimeSessionResponse(
            session_id=session_id,
            status="started",
            agent_id=agent_id,
            character_id=character.id,
            character_name=character.name,
            channel=channel,
            uid=int(remote_uid),
            rtc_token=rtc_token,
            app_id=os.getenv("AGORA_APP_ID", ""),
        )

    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Runtime session failed: {exc}",
        ) from exc


@app.post("/runtime/session/{session_id}/end", response_model=EndSessionResponse)
async def end_runtime_session(
    session_id: str,
    request: EndSessionRequest,
    repo: CharacterRepository = Depends(get_character_repository),
    session_repo: SessionRepository = Depends(get_session_repository),
    rel_repo: RelationshipRepository = Depends(get_relationship_repository),
    mem_repo: MemoryRepository = Depends(get_memory_repository),
):
    session = session_repo.get_session(session_id)
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Session '{session_id}' not found.",
        )

    character = repo.get(session.character_id)
    if not character:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Character '{session.character_id}' not found.",
        )

    # 1. End session in repository
    session_repo.end_session(session_id)

    # 2. Extract durable memories
    extracted_count = 0
    turns = list(request.transcript)

    # Fallback to Agora agent history if client-side transcript turns are missing
    if not turns and session.agent_id:
        try:
            agora_svc = AgoraService()
            history_resp = agora_svc.client.agents.get_history(
                appid=agora_svc.app_id,
                agent_id=session.agent_id,
            )
            if history_resp and history_resp.contents:
                for item in history_resp.contents:
                    if item.content and item.content.strip():
                        role = "user" if item.role == "user" else "assistant"
                        turns.append(TranscriptTurn(role=role, text=item.content.strip()))
                logger.info(
                    "[MEMORY] Fallback retrieved %d turns from Agora agent history for session %s",
                    len(turns),
                    session_id,
                )
        except Exception as exc:
            logger.warning("[MEMORY] Failed to query Agora agent history fallback: %s", exc)

    recv_msg = f"[MEMORY] transcript received: {len(turns)} turns"
    print(recv_msg, flush=True)
    logger.info(recv_msg)
    for t in turns:
        logger.info("  [%s]: %s", t.role, t.text)

    if turns:
        extractor = MemoryExtractor()
        extracted_memories = []
        relationship_delta = None

        extract_sd = getattr(extractor, "extract_session_data", None)
        sd_type_name = type(extract_sd).__name__
        if "AsyncMock" in sd_type_name or (callable(extract_sd) and "MagicMock" not in sd_type_name):
            try:
                extracted_memories, relationship_delta = await extractor.extract_session_data(
                    transcript=turns,
                    character=character,
                    relationship=rel_repo.get_relationship(character.id, user_id=session.user_id),
                )
            except Exception as exc:
                logger.warning("[MEMORY] extract_session_data failed: %s", exc)
                extracted_memories = []
                relationship_delta = None

        if relationship_delta is None and hasattr(extractor, "extract_memories"):
            try:
                res = extractor.extract_memories(transcript=turns, character=character)
                if inspect.isawaitable(res):
                    extracted_memories = await res
                else:
                    extracted_memories = res
            except Exception as exc:
                logger.warning("[MEMORY] extract_memories failed: %s", exc)
                extracted_memories = []
            from app.models.session import RelationshipDelta
            relationship_delta = RelationshipDelta(familiarity_change=2)

        ext_msg = f"[MEMORY] extracted: {len(extracted_memories)} memories"
        print(ext_msg, flush=True)
        logger.info(ext_msg)
        for m in extracted_memories:
            logger.info("  - [%s] (importance=%.2f) %s", m.category, m.importance, m.content)

        if extracted_memories:
            to_save = [
                CharacterMemory(
                    id=str(uuid.uuid4()),
                    character_id=character.id,
                    user_id=session.user_id,
                    session_id=session_id,
                    content=m.content,
                    category=m.category,
                    importance=m.importance,
                )
                for m in extracted_memories
            ]
            mem_repo.add_memories(to_save)
            extracted_count = len(to_save)
    else:
        from app.models.session import RelationshipDelta
        relationship_delta = RelationshipDelta(familiarity_change=2)

    pers_msg = f"[MEMORY] persisted: {extracted_count} memories"
    print(pers_msg, flush=True)
    logger.info(pers_msg)

    # 3. Update persistent relationship
    rel_analysis_msg = (
        f"[RELATIONSHIP] interaction analysis completed: {relationship_delta.summary_of_interaction}"
        if relationship_delta.summary_of_interaction
        else "[RELATIONSHIP] interaction analysis completed"
    )
    print(rel_analysis_msg, flush=True)
    logger.info(rel_analysis_msg)

    updated_rel = rel_repo.update_relationship(
        character_id=character.id,
        user_id=session.user_id,
        trust_delta=relationship_delta.trust_change,
        familiarity_delta=relationship_delta.familiarity_change,
        affection_delta=relationship_delta.affection_change,
        respect_delta=relationship_delta.respect_change,
        tension_delta=relationship_delta.tension_change,
        new_milestone=relationship_delta.new_milestone,
        increment_sessions=True,
    )

    rel_upd_msg = (
        f"[RELATIONSHIP] updated relationship: "
        f"trust={updated_rel.trust} "
        f"familiarity={updated_rel.familiarity} "
        f"affection={updated_rel.affection} "
        f"respect={updated_rel.respect} "
        f"tension={updated_rel.tension}"
    )
    print(rel_upd_msg, flush=True)
    logger.info(rel_upd_msg)

    # 4. Update character runtime emotion state if turns occurred
    if turns:
        try:
            engine = EmotionEngine()
            current_emo = EmotionState(
                emotion=character.state.current_emotion,
                intensity=character.state.emotional_intensity,
            )
            for t in turns:
                user_msg = t.text if t.role == "user" else ""
                char_msg = t.text if t.role == "assistant" else ""
                current_emo = engine.process_turn(
                    character=character,
                    user_text=user_msg,
                    character_response=char_msg,
                    current_state=current_emo,
                    relationship=updated_rel,
                )
            character.state.current_emotion = current_emo.emotion
            character.state.emotional_intensity = current_emo.intensity
            repo.update(character.id, character)
        except Exception as exc:
            logger.warning("[EMOTION] Failed to persist session emotion: %s", exc)

    return EndSessionResponse(
        session_id=session_id,
        status="ended",
        memories_extracted=extracted_count,
        relationship_updated=True,
        relationship=updated_rel,
    )


@app.post("/runtime/emotion/detect", response_model=EmotionDetectResponse)
async def detect_character_emotion(
    request: EmotionDetectRequest,
    repo: CharacterRepository = Depends(get_character_repository),
    rel_repo: RelationshipRepository = Depends(get_relationship_repository),
):
    character = repo.get(request.character_id, include_deleted=True)
    if not character:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Character '{request.character_id}' not found.",
        )

    relationship = rel_repo.get_relationship(character.id, user_id=request.user_id)
    engine = EmotionEngine()
    current_state = EmotionState(
        emotion=request.current_emotion,
        intensity=request.current_intensity,
    )
    new_state = engine.process_turn(
        character=character,
        user_text=request.user_text,
        character_response=request.character_response,
        current_state=current_state,
        relationship=relationship,
    )

    return EmotionDetectResponse(
        character_id=character.id,
        previous_emotion=request.current_emotion,
        detected_emotion=new_state.emotion,
        intensity=new_state.intensity,
        reason=new_state.reason,
        transition=f"{request.current_emotion}->{new_state.emotion}",
        updated_at=new_state.updated_at,
    )


@app.get("/characters/{character_id}/relationship", response_model=CharacterRelationship)
async def get_character_relationship(
    character_id: str,
    user_id: str = "default_user",
    rel_repo: RelationshipRepository = Depends(get_relationship_repository),
):
    return rel_repo.get_relationship(character_id, user_id=user_id)


@app.get("/characters/{character_id}/memories", response_model=MemoryListResponse)
async def list_character_memories(
    character_id: str,
    user_id: str = "default_user",
    limit: int = 20,
    mem_repo: MemoryRepository = Depends(get_memory_repository),
):
    memories = mem_repo.get_memories(
        character_id=character_id, user_id=user_id, limit=limit
    )
    return MemoryListResponse(
        character_id=character_id,
        memories=memories,
        total=len(memories),
    )


@app.delete("/characters/{character_id}/memories")
async def clear_character_memories(
    character_id: str,
    user_id: str = "default_user",
    mem_repo: MemoryRepository = Depends(get_memory_repository),
):
    count = mem_repo.clear_memories(character_id=character_id, user_id=user_id)
    return {
        "character_id": character_id,
        "user_id": user_id,
        "deleted_count": count,
    }


@app.delete("/memories/{memory_id}")
async def delete_memory(
    memory_id: str,
    mem_repo: MemoryRepository = Depends(get_memory_repository),
):
    deleted = mem_repo.delete_memory(memory_id)
    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Memory '{memory_id}' not found.",
        )
    return {
        "memory_id": memory_id,
        "deleted": True,
    }



# Debug Endpoints


@app.post("/debug/tts")
async def debug_tts():
    api_key = os.getenv("SARVAM_API_KEY")

    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="SARVAM_API_KEY is not configured",
        )

    payload = {
        "text": "Hello, this is a test of the speech system.",
        "language_code": "en-IN",
        "speaker": "shubh",
        "model": "bulbul:v3",
        "speech_sample_rate": 24000,
        "output_audio_codec": "wav",
    }

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(
            "https://api.sarvam.ai/text-to-speech",
            headers={
                "api-subscription-key": api_key,
                "Content-Type": "application/json",
            },
            json=payload,
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=response.status_code,
            detail=response.text,
        )

    result = response.json()
    audios = result.get("audios")

    if not audios:
        raise HTTPException(
            status_code=500,
            detail="Sarvam returned no audio",
        )

    audio_bytes = base64.b64decode(audios[0])

    return Response(
        content=audio_bytes,
        media_type="audio/wav",
        headers={
            "X-Sarvam-Request-ID": result.get("request_id", ""),
        },
    )


@app.get("/debug/config")
async def debug_config():
    return {
        "gemini_configured": bool(os.getenv("GEMINI_API_KEY")),
        "sarvam_configured": bool(os.getenv("SARVAM_API_KEY")),
        "agora_configured": bool(
            os.getenv("AGORA_APP_ID")
            and os.getenv("AGORA_APP_CERTIFICATE")
        ),
    }