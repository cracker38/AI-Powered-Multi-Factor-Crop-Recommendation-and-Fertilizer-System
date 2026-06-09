"""Shared user profile serialization for API responses."""
from __future__ import annotations

import json
from typing import Any

from app.firestore_db import UserRecord
from app.schemas import FarmerFieldData, UserProfile


def parse_field_data(raw: Any) -> dict | None:
    if raw is None:
        return None
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, str) and raw.strip():
        try:
            data = json.loads(raw)
            return data if isinstance(data, dict) else None
        except json.JSONDecodeError:
            return None
    return None


def field_data_to_json(data: dict | FarmerFieldData | None) -> str | None:
    if data is None:
        return None
    if isinstance(data, FarmerFieldData):
        return json.dumps(data.model_dump())
    return json.dumps(data)


def user_to_profile(user: UserRecord) -> UserProfile:
    fd = user.field_data
    return UserProfile(
        id=user.uid,
        email=user.email,
        display_name=user.display_name,
        role=user.role,
        disabled=user.disabled,
        phone=user.phone,
        district=user.district,
        farm_size_ha=user.farm_size_ha,
        approval_status=user.approval_status or "approved",
        field_data=FarmerFieldData(**fd) if fd else None,
    )
