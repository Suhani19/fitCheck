import logging
import os
from pathlib import Path
from typing import Annotated

from dotenv import load_dotenv
import firebase_admin
from firebase_admin import auth, credentials
import google.auth.credentials
from fastapi import Depends, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.db.models import UserModel

# Ensure backend/.env is loaded regardless of working directory
_backend_dir = Path(__file__).resolve().parent.parent.parent
_env_path = _backend_dir / ".env"
if _env_path.exists():
    load_dotenv(dotenv_path=_env_path)
else:
    load_dotenv()

logger = logging.getLogger(__name__)

security = HTTPBearer(auto_error=False)

_firebase_initialized = False


class _DevPublicCertCredential(credentials.Base):
    """Local development credential for Firebase Admin SDK.

    Allows TokenVerifier to verify ID token cryptographic signatures and claims
    against Google's public x509 certificates without requiring Google Cloud
    Application Default Credentials or a downloaded service account file.
    """

    def get_credential(self):
        return google.auth.credentials.AnonymousCredentials()


def init_firebase() -> None:
    """Initialize Firebase Admin SDK once."""
    global _firebase_initialized
    if _firebase_initialized or firebase_admin._apps:
        _firebase_initialized = True
        return

    service_account_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH")
    project_id = os.getenv("FIREBASE_PROJECT_ID", "fitcheck-by-overfit")

    try:
        if service_account_path and os.path.exists(service_account_path):
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred, options={"projectId": project_id})
            logger.info("Firebase Admin initialized with service account certificate for project: %s", project_id)
        else:
            # Use public cert verification credential with target project ID
            firebase_admin.initialize_app(_DevPublicCertCredential(), options={"projectId": project_id})
            logger.info("Firebase Admin initialized with public cert verification for project: %s", project_id)
        _firebase_initialized = True
    except Exception as exc:
        logger.warning("Firebase Admin initialization deferred/failed: %s", exc)


class AuthenticatedUser(BaseModel):
    uid: str
    email: str | None = None
    display_name: str | None = None


def get_current_user(
    auth_header: Annotated[HTTPAuthorizationCredentials | None, Security(security)],
    db: Session = Depends(get_db),
) -> AuthenticatedUser:
    """FastAPI dependency to verify Firebase ID token and return AuthenticatedUser.

    Rejects unauthenticated requests with 401 Unauthorized.
    Automatically syncs authenticated user record into database.
    """
    if not auth_header or not auth_header.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid authentication credentials.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    token = auth_header.credentials

    init_firebase()

    try:
        decoded_token = auth.verify_id_token(token)
    except Exception as exc:
        logger.warning("Token verification failed: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc

    uid = decoded_token.get("uid")
    if not uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token payload missing valid subject/uid.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    email = decoded_token.get("email")
    name = decoded_token.get("name") or decoded_token.get("display_name")

    # Sync user into local database if not exists
    try:
        user_record = db.query(UserModel).filter(UserModel.id == uid).first()
        if not user_record:
            user_record = UserModel(
                id=uid,
                email=email,
                display_name=name,
            )
            db.add(user_record)
            db.commit()
    except Exception as db_exc:
        logger.warning("Failed to auto-sync user record into database: %s", db_exc)
        db.rollback()

    return AuthenticatedUser(
        uid=uid,
        email=email,
        display_name=name,
    )

