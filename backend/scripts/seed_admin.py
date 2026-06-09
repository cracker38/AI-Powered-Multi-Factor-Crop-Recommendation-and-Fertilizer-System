"""
Seed admin in Firebase Auth + Firestore users/{uid}.

Requires backend/firebase-service-account.json for Firestore writes.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import settings
from app.firebase_app import create_admin_user, disable_firebase_user
from app.firestore_db import get_user_by_email, upsert_user

# Previous default admin — demote in Firestore when migrating email.
_LEGACY_ADMIN_EMAIL = "it.elias38@gmail.com"


def _retire_legacy_admin(new_email: str) -> None:
    legacy = _LEGACY_ADMIN_EMAIL.strip().lower()
    if legacy == new_email:
        return
    old = get_user_by_email(legacy)
    if not old or old.uid is None:
        return
    upsert_user(
        old.uid,
        email=old.email,
        display_name=old.display_name or "Former Administrator",
        role="farmer",
        disabled=True,
    )
    disable_firebase_user(old.uid, True)
    print(f"Retired legacy admin in Firestore: users/{old.uid} ({legacy})")


def main() -> None:
    if not settings.admin_password or settings.admin_password == "change-me-before-deploy":
        print("Set ADMIN_PASSWORD in backend/.env before running seed.")
        sys.exit(1)

    email = settings.admin_email_normalized
    uid = create_admin_user(email, settings.admin_password)
    upsert_user(
        uid,
        email=email,
        display_name="System Administrator",
        role="admin",
        disabled=False,
        approval_status="approved",
    )
    _retire_legacy_admin(email)
    print(f"Admin seeded in Firestore: users/{uid}")
    print(f"  email: {email}")


if __name__ == "__main__":
    main()
