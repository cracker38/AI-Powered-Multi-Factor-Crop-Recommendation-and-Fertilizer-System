"""Firebase Realtime Database — soil sensor reads for admin approval."""
from __future__ import annotations

from dataclasses import dataclass

import requests

from app.config import settings
from app.schemas import FarmerFieldData

DEFAULT_DEVICE_ID = "ESP8266_SOIL_01"


@dataclass
class SensorReadingResult:
    field_data: FarmerFieldData
    source: str = "sensor"
    device_id: str | None = None
    user_uid: str | None = None
    updated_at_ms: int | None = None


def _get_json(path: str):
    secret = (settings.firebase_rtdb_secret or "").strip()
    base = (settings.firebase_rtdb_url or "").strip().rstrip("/")
    if not secret or not base:
        return None
    url = f"{base}{path}.json?auth={secret}"
    try:
        resp = requests.get(url, timeout=20)
        if resp.status_code != 200:
            return None
        return resp.json()
    except Exception:
        return None


def _clamp(value: object, lo: float, hi: float, default: float) -> float:
    try:
        v = float(value)
    except (TypeError, ValueError):
        v = default
    return max(lo, min(hi, v))


def _to_field_data(raw: dict) -> FarmerFieldData | None:
    if not raw:
        return None
    try:
        soil_ph = raw.get("soil_ph", raw.get("ph"))
        return FarmerFieldData(
            nitrogen=_clamp(raw.get("nitrogen"), 0, 500, 0),
            phosphorus=_clamp(raw.get("phosphorus"), 0, 500, 0),
            potassium=_clamp(raw.get("potassium"), 0, 500, 0),
            soil_moisture=_clamp(raw.get("soil_moisture"), 0, 100, 0),
            temperature_c=_clamp(raw.get("temperature_c"), -10, 55, 24),
            humidity_pct=_clamp(raw.get("humidity_pct"), 0, 100, 70),
            soil_ph=_clamp(soil_ph if soil_ph is not None else 6.5, 0, 14, 6.5),
            rainfall_mm=_clamp(raw.get("rainfall_mm"), 0, 2000, 200),
            soil_type=str(raw.get("soil_type") or "loam"),
        )
    except (TypeError, ValueError):
        return None


def _meta_from_raw(raw: dict, device_id: str | None = None) -> SensorReadingResult | None:
    parsed = _to_field_data(raw)
    if parsed is None:
        return None
    ts = raw.get("updated_at_ms")
    try:
        updated_at_ms = int(ts) if ts is not None else None
    except (TypeError, ValueError):
        updated_at_ms = None
    return SensorReadingResult(
        field_data=parsed,
        source=str(raw.get("source") or "sensor"),
        device_id=device_id or (str(raw.get("device_id")) if raw.get("device_id") else None),
        user_uid=str(raw.get("user_uid")) if raw.get("user_uid") else None,
        updated_at_ms=updated_at_ms,
    )


def _email_matches(raw: dict, user_email: str | None) -> bool:
    if not user_email:
        return False
    legacy_email = str(raw.get("email") or "").strip().lower()
    return legacy_email == user_email.strip().lower()


def _uid_matches(raw: dict, user_uid: str) -> bool:
    legacy_uid = str(raw.get("user_uid") or "")
    return legacy_uid == user_uid


def _pick_newest(candidates: list[SensorReadingResult]) -> SensorReadingResult | None:
    if not candidates:
        return None
    return max(candidates, key=lambda c: c.updated_at_ms or 0)


def _scan_user_devices(user_uid: str) -> SensorReadingResult | None:
    bucket = _get_json(f"/soil_sensors/{user_uid}")
    if not isinstance(bucket, dict):
        return None
    candidates: list[SensorReadingResult] = []
    for device_id, device_node in bucket.items():
        if not isinstance(device_node, dict):
            continue
        latest = device_node.get("latest")
        if isinstance(latest, dict):
            result = _meta_from_raw(latest, device_id=str(device_id))
            if result is not None:
                candidates.append(result)
    return _pick_newest(candidates)


def _scan_global_devices(user_uid: str, user_email: str | None) -> SensorReadingResult | None:
    bucket = _get_json("/soil_sensors")
    if not isinstance(bucket, dict):
        return None
    candidates: list[SensorReadingResult] = []
    for device_id, device_node in bucket.items():
        if not isinstance(device_node, dict):
            continue
        latest = device_node.get("latest")
        if not isinstance(latest, dict):
            continue
        if _uid_matches(latest, user_uid) or _email_matches(latest, user_email):
            result = _meta_from_raw(latest, device_id=str(device_id))
            if result is not None:
                candidates.append(result)
    return _pick_newest(candidates)


def fetch_sensor_field_data(
    user_uid: str,
    user_email: str | None = None,
    device_id: str = DEFAULT_DEVICE_ID,
) -> SensorReadingResult | None:
    """Load latest ESP8266 readings for the selected farmer (any bound device)."""
    direct_paths = [
        (f"/farmer_approval/{user_uid}/latest", None),
        (f"/soil_sensors/{user_uid}/{device_id}/latest", device_id),
        (f"/soil_sensors/{user_uid}/latest", None),
    ]
    candidates: list[SensorReadingResult] = []
    for path, dev in direct_paths:
        raw = _get_json(path)
        if isinstance(raw, dict):
            result = _meta_from_raw(raw, device_id=dev)
            if result is not None:
                candidates.append(result)

    scanned = _scan_user_devices(user_uid)
    if scanned is not None:
        candidates.append(scanned)

    global_match = _scan_global_devices(user_uid, user_email)
    if global_match is not None:
        candidates.append(global_match)

    return _pick_newest(candidates)


def find_pending_farmer_with_sensor(users: list) -> tuple[object, SensorReadingResult] | None:
    """Match a pending farmer to the active ESP8266 reading (by UID or email)."""
    pending = [
        u for u in users
        if getattr(u, "role", None) == "farmer"
        and (getattr(u, "approval_status", None) or "approved") == "pending"
    ]
    if not pending:
        return None
    for user in pending:
        reading = fetch_sensor_field_data(user.uid, user_email=user.email)
        if reading is not None:
            return user, reading
    return None
