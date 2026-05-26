"""
Seed admin in Firebase Auth + Firestore users/{uid}.

Requires backend/firebase-service-account.json for Firestore writes.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import settings
from app.firebase_app import create_admin_user
from app.firestore_db import upsert_user


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
    )
    print(f"Admin seeded in Firestore: users/{uid}")
    print(f"  email: {email}")


if __name__ == "__main__":
    main()
