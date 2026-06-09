"""Cloud Firestore data access (replaces SQLite)."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore_v1 import SERVER_TIMESTAMP, FieldFilter

from app.firebase_app import get_firestore_client
from app.user_profile_utils import parse_field_data, field_data_to_json

USERS = "users"
PREDICTIONS = "predictions"
DATASETS = "training_datasets"
SYSTEM = "system"
ACTIVITY_LOGS = "activity_logs"
NOTIFICATIONS = "notifications"
OUTCOME_FEEDBACK = "outcome_feedback"


@dataclass
class UserRecord:
    uid: str
    email: str
    display_name: str | None
    role: str
    disabled: bool
    phone: str | None = None
    district: str | None = None
    farm_size_ha: float | None = None
    approval_status: str = "approved"
    field_data: dict | None = None
    created_at: datetime | None = None

    @property
    def id(self) -> str:
        return self.uid

    @property
    def is_approved(self) -> bool:
        return self.role == "admin" or self.approval_status == "approved"


def _db():
    return get_firestore_client()


def _ts_to_dt(value: Any) -> datetime | None:
    if value is None:
        return None
    if hasattr(value, "timestamp"):
        return datetime.fromtimestamp(value.timestamp(), tz=timezone.utc)
    if isinstance(value, datetime):
        return value
    return None


def _user_from_doc(uid: str, data: dict) -> UserRecord:
    return UserRecord(
        uid=uid,
        email=data.get("email", ""),
        display_name=data.get("display_name"),
        role=data.get("role", "farmer"),
        disabled=bool(data.get("disabled", False)),
        phone=data.get("phone"),
        district=data.get("district"),
        farm_size_ha=data.get("farm_size_ha"),
        approval_status=data.get("approval_status") or "approved",
        field_data=parse_field_data(data.get("field_data")),
        created_at=_ts_to_dt(data.get("created_at")),
    )


def get_user(uid: str) -> UserRecord | None:
    snap = _db().collection(USERS).document(uid).get()
    if not snap.exists:
        return None
    return _user_from_doc(snap.id, snap.to_dict() or {})


def get_user_by_email(email: str) -> UserRecord | None:
    q = _db().collection(USERS).where(filter=FieldFilter("email", "==", email)).limit(1)
    for snap in q.stream():
        return _user_from_doc(snap.id, snap.to_dict() or {})
    return None


def list_users() -> list[UserRecord]:
    snaps = _db().collection(USERS).order_by("created_at", direction="DESCENDING").stream()
    return [_user_from_doc(s.id, s.to_dict() or {}) for s in snaps]


def upsert_user(
    uid: str,
    *,
    email: str,
    display_name: str | None,
    role: str,
    disabled: bool = False,
    phone: str | None = None,
    district: str | None = None,
    farm_size_ha: float | None = None,
    approval_status: str | None = None,
    field_data: dict | None = None,
) -> UserRecord:
    ref = _db().collection(USERS).document(uid)
    existing = ref.get()
    payload: dict[str, Any] = {
        "email": email,
        "display_name": display_name,
        "role": role,
        "disabled": disabled,
        "updated_at": SERVER_TIMESTAMP,
    }
    if phone is not None:
        payload["phone"] = phone
    if district is not None:
        payload["district"] = district
    if farm_size_ha is not None:
        payload["farm_size_ha"] = farm_size_ha
    if approval_status is not None:
        payload["approval_status"] = approval_status
    elif not existing.exists and role == "farmer":
        payload["approval_status"] = "pending"
    if field_data is not None:
        payload["field_data"] = field_data
    if not existing.exists:
        payload["created_at"] = SERVER_TIMESTAMP
    ref.set(payload, merge=True)
    return get_user(uid)  # type: ignore[return-value]


def update_user(uid: str, **fields: Any) -> UserRecord | None:
    ref = _db().collection(USERS).document(uid)
    if not ref.get().exists:
        return None
    if "field_data" in fields:
        fd = fields.pop("field_data")
        fields["field_data"] = fd if isinstance(fd, dict) else fd
    fields["updated_at"] = SERVER_TIMESTAMP
    ref.update(fields)
    return get_user(uid)


def delete_user(uid: str) -> bool:
    ref = _db().collection(USERS).document(uid)
    if not ref.get().exists:
        return False
    ref.delete()
    return True


def create_prediction(uid: str, data: dict[str, Any]) -> str:
    data = {**data, "user_uid": uid, "created_at": SERVER_TIMESTAMP}
    ref = _db().collection(PREDICTIONS).document()
    ref.set(data)
    return ref.id


def list_predictions_for_user(uid: str, limit: int = 30) -> list[dict[str, Any]]:
    q = (
        _db()
        .collection(PREDICTIONS)
        .where(filter=FieldFilter("user_uid", "==", uid))
        .order_by("created_at", direction="DESCENDING")
        .limit(limit)
    )
    out = []
    for snap in q.stream():
        row = snap.to_dict() or {}
        row["id"] = snap.id
        out.append(row)
    return out


def count_predictions() -> int:
    return sum(1 for _ in _db().collection(PREDICTIONS).stream())


def crop_distribution() -> dict[str, int]:
    """Count recommended crops across all stored predictions."""
    counts: dict[str, int] = {}
    for snap in _db().collection(PREDICTIONS).stream():
        crop = str((snap.to_dict() or {}).get("top_crop", "")).strip().lower()
        if not crop:
            continue
        counts[crop] = counts.get(crop, 0) + 1
    return dict(sorted(counts.items(), key=lambda item: -item[1]))


def list_recent_predictions(limit: int = 20) -> list[dict[str, Any]]:
    snaps = (
        _db()
        .collection(PREDICTIONS)
        .order_by("created_at", direction="DESCENDING")
        .limit(min(limit, 50))
        .stream()
    )
    out = []
    for snap in snaps:
        row = snap.to_dict() or {}
        row["id"] = snap.id
        out.append(row)
    return out


def count_farmers() -> int:
    q = _db().collection(USERS).where(filter=FieldFilter("role", "==", "farmer"))
    return sum(1 for _ in q.stream())


def count_active_farmers() -> int:
    n = 0
    for snap in _db().collection(USERS).where(filter=FieldFilter("role", "==", "farmer")).stream():
        data = snap.to_dict() or {}
        if not bool(data.get("disabled", False)) and (data.get("approval_status") or "approved") == "approved":
            n += 1
    return n


def count_disabled_farmers() -> int:
    return count_farmers() - count_active_farmers()


def prediction_counts_by_user() -> dict[str, int]:
    counts: dict[str, int] = {}
    for snap in _db().collection(PREDICTIONS).stream():
        uid = str((snap.to_dict() or {}).get("user_uid", ""))
        if uid:
            counts[uid] = counts.get(uid, 0) + 1
    return counts


def prediction_count_for_user(uid: str) -> int:
    q = _db().collection(PREDICTIONS).where(filter=FieldFilter("user_uid", "==", uid))
    return sum(1 for _ in q.stream())


def log_activity(
    *,
    actor_uid: str,
    actor_email: str,
    action: str,
    category: str,
    detail: str = "",
    severity: str = "info",
) -> str:
    ref = _db().collection(ACTIVITY_LOGS).document()
    ref.set(
        {
            "actor_uid": actor_uid,
            "actor_email": actor_email,
            "action": action,
            "category": category,
            "detail": detail,
            "severity": severity,
            "created_at": SERVER_TIMESTAMP,
        }
    )
    return ref.id


def list_activity_logs(limit: int = 40) -> list[dict[str, Any]]:
    snaps = (
        _db()
        .collection(ACTIVITY_LOGS)
        .order_by("created_at", direction="DESCENDING")
        .limit(min(limit, 100))
        .stream()
    )
    out = []
    for snap in snaps:
        row = snap.to_dict() or {}
        row["id"] = snap.id
        out.append(row)
    return out


def create_notification(
    *,
    title: str,
    message: str,
    category: str = "system",
    severity: str = "info",
) -> str:
    ref = _db().collection(NOTIFICATIONS).document()
    ref.set(
        {
            "title": title,
            "message": message,
            "category": category,
            "severity": severity,
            "read": False,
            "created_at": SERVER_TIMESTAMP,
        }
    )
    return ref.id


def list_notifications(limit: int = 30) -> list[dict[str, Any]]:
    snaps = (
        _db()
        .collection(NOTIFICATIONS)
        .order_by("created_at", direction="DESCENDING")
        .limit(min(limit, 50))
        .stream()
    )
    out = []
    for snap in snaps:
        row = snap.to_dict() or {}
        row["id"] = snap.id
        out.append(row)
    return out


def mark_notification_read(doc_id: str) -> bool:
    ref = _db().collection(NOTIFICATIONS).document(doc_id)
    if not ref.get().exists:
        return False
    ref.update({"read": True, "updated_at": SERVER_TIMESTAMP})
    return True


def delete_dataset(doc_id: str) -> bool:
    ref = _db().collection(DATASETS).document(doc_id)
    if not ref.get().exists:
        return False
    ref.delete()
    return True


def update_dataset(doc_id: str, **fields: Any) -> dict[str, Any] | None:
    ref = _db().collection(DATASETS).document(doc_id)
    if not ref.get().exists:
        return None
    fields["updated_at"] = SERVER_TIMESTAMP
    ref.update(fields)
    return get_dataset(doc_id)


def list_datasets() -> list[dict[str, Any]]:
    snaps = _db().collection(DATASETS).order_by("created_at", direction="DESCENDING").stream()
    out = []
    for s in snaps:
        row = s.to_dict() or {}
        row["id"] = s.id
        out.append(row)
    return out


def create_dataset(data: dict[str, Any]) -> str:
    data = {**data, "created_at": SERVER_TIMESTAMP}
    ref = _db().collection(DATASETS).document()
    ref.set(data)
    return ref.id


def get_dataset(doc_id: str) -> dict[str, Any] | None:
    snap = _db().collection(DATASETS).document(doc_id).get()
    if not snap.exists:
        return None
    row = snap.to_dict() or {}
    row["id"] = snap.id
    return row


def set_active_dataset(doc_id: str) -> None:
    for snap in _db().collection(DATASETS).stream():
        snap.reference.update({"is_active": snap.id == doc_id, "updated_at": SERVER_TIMESTAMP})


def count_datasets() -> int:
    return sum(1 for _ in _db().collection(DATASETS).stream())


def save_model_meta(meta: dict[str, Any]) -> None:
    _db().collection(SYSTEM).document("model").set({**meta, "updated_at": SERVER_TIMESTAMP}, merge=True)


def get_model_meta() -> dict[str, Any] | None:
    snap = _db().collection(SYSTEM).document("model").get()
    return snap.to_dict() if snap.exists else None


FARMER_TIPS = "farmer_tips"


def list_farmer_tips(limit: int = 10) -> list[dict[str, Any]]:
    snaps = (
        _db()
        .collection(FARMER_TIPS)
        .order_by("created_at", direction="DESCENDING")
        .limit(min(limit, 20))
        .stream()
    )
    out = []
    for s in snaps:
        row = s.to_dict() or {}
        row["id"] = s.id
        out.append(row)
    return out


def get_prediction(doc_id: str, user_uid: str) -> dict[str, Any] | None:
    snap = _db().collection(PREDICTIONS).document(doc_id).get()
    if not snap.exists:
        return None
    row = snap.to_dict() or {}
    if row.get("user_uid") != user_uid:
        return None
    row["id"] = snap.id
    return row


def get_prediction_by_id(doc_id: str) -> dict[str, Any] | None:
    snap = _db().collection(PREDICTIONS).document(doc_id).get()
    if not snap.exists:
        return None
    row = snap.to_dict() or {}
    row["id"] = snap.id
    return row


def fertilizer_usage_stats() -> dict[str, int]:
    """Count fertilizer product recommendations across all predictions."""
    counts: dict[str, int] = {}
    for snap in _db().collection(PREDICTIONS).stream():
        for f in (snap.to_dict() or {}).get("fertilizers") or []:
            if isinstance(f, dict):
                name = str(f.get("name", "Unknown")).strip() or "Unknown"
            else:
                name = "Unknown"
            counts[name] = counts.get(name, 0) + 1
    return dict(sorted(counts.items(), key=lambda x: -x[1])[:15])


def avg_soil_health_score() -> float:
    scores: list[float] = []
    for snap in _db().collection(PREDICTIONS).stream():
        v = (snap.to_dict() or {}).get("soil_health_score")
        if v is not None:
            try:
                scores.append(float(v))
            except (TypeError, ValueError):
                pass
    if not scores:
        return 0.0
    return round(sum(scores) / len(scores), 1)


def create_outcome_feedback(
    user_uid: str,
    *,
    prediction_id: str,
    recommended_crop: str,
    yield_rating: int,
    crop_grown: str | None,
    followed_fertilizer: bool,
    notes: str | None,
) -> str:
    existing = (
        _db()
        .collection(OUTCOME_FEEDBACK)
        .where(filter=FieldFilter("prediction_id", "==", prediction_id))
        .where(filter=FieldFilter("user_uid", "==", user_uid))
        .limit(1)
        .stream()
    )
    for snap in existing:
        raise ValueError("Feedback already submitted for this prediction")

    ref = _db().collection(OUTCOME_FEEDBACK).document()
    ref.set(
        {
            "user_uid": user_uid,
            "prediction_id": prediction_id,
            "recommended_crop": recommended_crop,
            "crop_grown": crop_grown,
            "yield_rating": yield_rating,
            "followed_fertilizer": followed_fertilizer,
            "notes": notes or "",
            "created_at": SERVER_TIMESTAMP,
        }
    )
    return ref.id


def get_feedback_for_prediction(prediction_id: str, user_uid: str) -> dict[str, Any] | None:
    q = (
        _db()
        .collection(OUTCOME_FEEDBACK)
        .where(filter=FieldFilter("prediction_id", "==", prediction_id))
        .where(filter=FieldFilter("user_uid", "==", user_uid))
        .limit(1)
    )
    for snap in q.stream():
        row = snap.to_dict() or {}
        row["id"] = snap.id
        return row
    return None


def list_outcome_feedback_for_user(user_uid: str, limit: int = 30) -> list[dict[str, Any]]:
    q = (
        _db()
        .collection(OUTCOME_FEEDBACK)
        .where(filter=FieldFilter("user_uid", "==", user_uid))
        .order_by("created_at", direction="DESCENDING")
        .limit(min(limit, 50))
    )
    out = []
    for snap in q.stream():
        row = snap.to_dict() or {}
        row["id"] = snap.id
        out.append(row)
    return out


def outcome_analytics() -> dict[str, Any]:
    total = 0
    rating_sum = 0
    followed = 0
    for snap in _db().collection(OUTCOME_FEEDBACK).stream():
        row = snap.to_dict() or {}
        total += 1
        rating_sum += int(row.get("yield_rating", 0))
        if row.get("followed_fertilizer"):
            followed += 1
    avg_rating = round(rating_sum / total, 2) if total else None
    follow_pct = round(100.0 * followed / total, 1) if total else None
    return {
        "outcome_feedback_count": total,
        "avg_outcome_rating": avg_rating,
        "fertilizer_follow_rate_pct": follow_pct,
    }
