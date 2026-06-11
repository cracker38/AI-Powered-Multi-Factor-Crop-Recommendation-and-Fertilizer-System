"""Firebase Realtime Database — soil sensor reads for admin approval."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

import requests

from app.config import settings
from app.schemas import FarmerFieldData, SensorFieldDataRaw

DEFAULT_DEVICE_ID = "ESP8266_SOIL_01"
PENDING_SENSOR_PATH = "/pending_farmer_sensor/latest"


@dataclass
class SensorReadingResult:
    field_data: SensorFieldDataRaw
    source: str = "sensor"
    device_id: str | None = None
    user_uid: str | None = None
    updated_at_ms: int | None = None
    raw: dict | None = None


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


def _to_field_data(raw: dict) -> SensorFieldDataRaw | None:
    if not raw:
        return None
    try:
        soil_ph = raw.get("soil_ph", raw.get("ph"))
        ec = raw.get("ec_us_cm")
        return SensorFieldDataRaw(
            nitrogen=float(raw.get("nitrogen", 0)),
            phosphorus=float(raw.get("phosphorus", 0)),
            potassium=float(raw.get("potassium", 0)),
            soil_moisture=float(raw.get("soil_moisture", 0)),
            temperature_c=float(raw.get("temperature_c", 24)),
            humidity_pct=float(raw.get("humidity_pct", 70)),
            soil_ph=float(soil_ph if soil_ph is not None else 6.5),
            rainfall_mm=float(raw.get("rainfall_mm", 200)),
            soil_type=str(raw.get("soil_type") or "loam"),
            ec_us_cm=float(ec) if ec is not None else None,
        )
    except (TypeError, ValueError):
        return None


def _meta_from_raw(
    raw: dict,
    device_id: str | None = None,
) -> SensorReadingResult | None:
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
        raw=raw,
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


def get_latest_pending_farmer(users: list):
    pending = [
        u
        for u in users
        if getattr(u, "role", None) == "farmer"
        and (getattr(u, "approval_status", None) or "approved") == "pending"
    ]
    if not pending:
        return None

    def sort_key(u):
        created = getattr(u, "created_at", None)
        if created is None:
            return datetime.min.replace(tzinfo=timezone.utc)
        if created.tzinfo is None:
            return created.replace(tzinfo=timezone.utc)
        return created

    return max(pending, key=sort_key)


def fetch_latest_global_sensor() -> SensorReadingResult | None:
    """Latest ESP8266 reading — auto-linked to the last pending farmer."""
    candidates: list[SensorReadingResult] = []

    for path, dev in [
        (PENDING_SENSOR_PATH, DEFAULT_DEVICE_ID),
        (f"/soil_sensors/{DEFAULT_DEVICE_ID}/latest", DEFAULT_DEVICE_ID),
    ]:
        raw = _get_json(path)
        if isinstance(raw, dict):
            result = _meta_from_raw(raw, device_id=dev)
            if result is not None:
                candidates.append(result)

    bucket = _get_json("/soil_sensors")
    if isinstance(bucket, dict):
        for key, node in bucket.items():
            if not isinstance(node, dict):
                continue
            if "latest" in node and isinstance(node["latest"], dict):
                result = _meta_from_raw(node["latest"], device_id=str(key))
                if result is not None:
                    candidates.append(result)
            elif "nitrogen" in node or "soil_moisture" in node:
                result = _meta_from_raw(node, device_id=str(key))
                if result is not None:
                    candidates.append(result)
            else:
                for device_id, device_node in node.items():
                    if not isinstance(device_node, dict):
                        continue
                    latest = device_node.get("latest")
                    if isinstance(latest, dict):
                        result = _meta_from_raw(latest, device_id=str(device_id))
                        if result is not None:
                            candidates.append(result)

    return _pick_newest(candidates)


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
    all_users: list | None = None,
) -> SensorReadingResult | None:
    """Load ESP8266 readings for admin approval."""
    if all_users:
        latest_pending = get_latest_pending_farmer(all_users)
        if latest_pending is not None and latest_pending.uid == user_uid:
            global_reading = fetch_latest_global_sensor()
            if global_reading is not None:
                return global_reading

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
    """Last pending farmer + latest ESP8266 reading from RTDB."""
    latest_pending = get_latest_pending_farmer(users)
    if latest_pending is None:
        return None

    reading = fetch_latest_global_sensor()
    if reading is not None:
        return latest_pending, reading

    reading = fetch_sensor_field_data(
        latest_pending.uid,
        user_email=latest_pending.email,
        all_users=users,
    )
    if reading is not None:
        return latest_pending, reading
    return None
