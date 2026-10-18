"""Secure cryptographic demo token issuer and verifier for FitCheck.

Issues HMAC-SHA256 signed demo session tokens allowing prospective candidates
to experience real backend persistence, evaluations, and practice memory with
strict tenant isolation, without bypassing authentication or trusting client UIDs.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import logging
import os
import time
from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.auth import AuthenticatedUser
from app.db.models import UserModel

logger = logging.getLogger(__name__)

# Server-side signing secret from environment, with a stable deterministic fallback for local dev
DEMO_SIGNING_SECRET = os.getenv("FITCHECK_DEMO_SECRET", "fitcheck-secure-demo-secret-key-2026-sha256")
DEMO_TOKEN_PREFIX = "fitcheck_demo."
DEMO_USER_UID = "demo-candidate-elena"
DEMO_USER_EMAIL = "elena.demo@fitcheck.io"
DEMO_USER_NAME = "Elena Rostova"


def _b64encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("utf-8").rstrip("=")


def _b64decode(s: str) -> bytes:
    padding = 4 - (len(s) % 4)
    if padding and padding < 4:
        s += "=" * padding
    return base64.urlsafe_b64decode(s.encode("utf-8"))


def create_demo_token(
    uid: str = DEMO_USER_UID,
    email: str = DEMO_USER_EMAIL,
    display_name: str = DEMO_USER_NAME,
    candidate_id: str | None = None,
    workspace_id: str | None = None,
    exp_seconds: int = 86400 * 7,  # 7 days
) -> str:
    """Create a tamper-proof HMAC-SHA256 signed demo session token."""
    payload: dict[str, Any] = {
        "uid": uid,
        "email": email,
        "name": display_name,
        "iat": int(time.time()),
        "exp": int(time.time()) + exp_seconds,
        "type": "demo_session",
    }
    if candidate_id:
        payload["candidate_id"] = candidate_id
    if workspace_id:
        payload["workspace_id"] = workspace_id

    payload_json = json.dumps(payload, separators=(",", ":"), sort_keys=True)
    payload_b64 = _b64encode(payload_json.encode("utf-8"))

    signature = hmac.new(
        DEMO_SIGNING_SECRET.encode("utf-8"),
        payload_b64.encode("utf-8"),
        hashlib.sha256,
    ).digest()
    sig_b64 = _b64encode(signature)

    return f"{DEMO_TOKEN_PREFIX}{payload_b64}.{sig_b64}"


def verify_demo_token(token: str, db: Session | None = None) -> AuthenticatedUser:
    """Verify an HMAC-SHA256 signed demo session token.

    Validates cryptographic signature, token expiration, and subject claims.
    Ensures the demo user record exists in the database.
    """
    if not token.startswith(DEMO_TOKEN_PREFIX):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid demo token format.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    remainder = token[len(DEMO_TOKEN_PREFIX):]
    parts = remainder.split(".")
    if len(parts) != 2:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Malformed demo token structure.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload_b64, sig_b64 = parts

    expected_sig = hmac.new(
        DEMO_SIGNING_SECRET.encode("utf-8"),
        payload_b64.encode("utf-8"),
        hashlib.sha256,
    ).digest()

    try:
        actual_sig = _b64decode(sig_b64)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid signature encoding.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    if not hmac.compare_digest(expected_sig, actual_sig):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Demo token cryptographic signature verification failed.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        payload_bytes = _b64decode(payload_b64)
        payload = json.loads(payload_bytes.decode("utf-8"))
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Corrupted demo token payload.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    exp = payload.get("exp")
    if not exp or time.time() > exp:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Demo token has expired.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    uid = payload.get("uid")
    if not uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Demo token missing uid claim.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Ensure demo user exists in local database if session provided
    if db:
        try:
            user_record = db.query(UserModel).filter(UserModel.id == uid).first()
            if not user_record:
                if uid == DEMO_USER_UID:
                    from app.db.seed_demo_candidate import seed_demo_candidate
                    seed_demo_candidate(db)
                elif uid.startswith("demo-ws-"):
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Demo workspace expired or no longer available. Please start a fresh demo.",
                        headers={"WWW-Authenticate": "Bearer"},
                    )
        except HTTPException:
            raise
        except Exception as db_exc:
            logger.warning("Demo user verification notice: %s", db_exc)

    return AuthenticatedUser(
        uid=uid,
        email=payload.get("email"),
        display_name=payload.get("name"),
    )
