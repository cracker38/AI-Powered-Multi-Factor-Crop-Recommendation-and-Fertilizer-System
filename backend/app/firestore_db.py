"""Data access — SQLite (local) or Cloud Firestore (production)."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from app.config import settings


@dataclass
class UserRecord:
    uid: str
    email: str
    display_name: str | None
    role: str
    disabled: bool
    phone: str | None = None
    district: str | None = None
    created_at: datetime | None = None

    @property
    def id(self) -> str:
        return self.uid


if settings.storage_backend == "sqlite":
    from app.sqlite_backend import *  # noqa: F401,F403
else:
    from app.firestore_native import *  # noqa: F401,F403
