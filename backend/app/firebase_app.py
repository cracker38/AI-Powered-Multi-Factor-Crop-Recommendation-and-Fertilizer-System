from __future__ import annotations

from pathlib import Path

import firebase_admin
from firebase_admin import auth, credentials, firestore
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from app.config import settings

_initialized = False
_use_admin_sdk = False


def _credentials_file_exists() -> bool:
    p = Path(settings.firebase_credentials_path)
    return p.is_file()


def ensure_firebase() -> None:
    global _initialized, _use_admin_sdk
    if _initialized:
        return
    if _credentials_file_exists():
        cred = credentials.Certificate(settings.firebase_credentials_path)
        firebase_admin.initialize_app(cred)
        _use_admin_sdk = True
    _initialized = True


def verify_id_token(token: str) -> dict:
    ensure_firebase()
    if _use_admin_sdk:
        return auth.verify_id_token(token)
    return google_id_token.verify_firebase_token(
        token,
        google_requests.Request(),
        audience=settings.firebase_project_id,
    )


def create_admin_user(email: str, password: str) -> str:
    """Create or resolve admin Firebase user (Admin SDK or Identity Toolkit REST)."""
    ensure_firebase()
    if _use_admin_sdk:
        try:
            user = auth.get_user_by_email(email)
            return user.uid
        except auth.UserNotFoundError:
            user = auth.create_user(email=email, password=password, email_verified=True)
            return user.uid

    import requests

    api_key = settings.firebase_web_api_key
    sign_in = requests.post(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={api_key}",
        json={"email": email, "password": password, "returnSecureToken": True},
        timeout=30,
    )
    if sign_in.ok:
        return sign_in.json()["localId"]

    sign_up = requests.post(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={api_key}",
        json={"email": email, "password": password, "returnSecureToken": True},
        timeout=30,
    )
    if not sign_up.ok:
        err = sign_up.json().get("error", {})
        raise RuntimeError(err.get("message", sign_up.text))
    return sign_up.json()["localId"]


def disable_firebase_user(uid: str, disabled: bool) -> None:
    ensure_firebase()
    if not _use_admin_sdk:
        return
    auth.update_user(uid, disabled=disabled)


def delete_firebase_user(uid: str) -> None:
    """Remove Firebase Auth account when Admin SDK is available."""
    ensure_firebase()
    if not _use_admin_sdk:
        return
    try:
        auth.delete_user(uid)
    except auth.UserNotFoundError:
        pass


def get_firestore_client():
    """Firestore requires Firebase Admin SDK (service account JSON)."""
    ensure_firebase()
    if not _use_admin_sdk:
        raise RuntimeError(
            "Firestore requires backend/firebase-service-account.json. "
            "Download from Firebase Console → Project settings → Service accounts → Generate key."
        )
    return firestore.client()
