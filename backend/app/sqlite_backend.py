"""SQLite storage when Firestore gRPC is unavailable (local Windows dev)."""
from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.database import SessionLocal, engine, init_db
from app.firestore_db import UserRecord
from app.models import CropPrediction, TrainingDataset, User

USERS = "users"
PREDICTIONS = "predictions"
DATASETS = "training_datasets"
SYSTEM = "system"
ACTIVITY_LOGS = "activity_logs"
NOTIFICATIONS = "notifications"
OUTCOME_FEEDBACK = "outcome_feedback"
FARMER_TIPS = "farmer_tips"

_schema_ready = False


def _ensure_schema() -> None:
    global _schema_ready
    if _schema_ready:
        return
    init_db()
    with engine.begin() as conn:
        for stmt in (
            "ALTER TABLE users ADD COLUMN phone TEXT",
            "ALTER TABLE users ADD COLUMN district TEXT",
        ):
            try:
                conn.execute(text(stmt))
            except Exception:
                pass
    _schema_ready = True


def _session() -> Session:
    _ensure_schema()
    return SessionLocal()


def _user_row_to_record(u: User) -> UserRecord:
    return UserRecord(
        uid=u.firebase_uid,
        email=u.email,
        display_name=u.display_name,
        role=u.role,
        disabled=bool(u.disabled),
        phone=getattr(u, "phone", None),
        district=getattr(u, "district", None),
        created_at=u.created_at,
    )


def _resolve_user(db: Session, firebase_uid: str) -> User | None:
    return db.query(User).filter(User.firebase_uid == firebase_uid).first()


def get_user(uid: str) -> UserRecord | None:
    with _session() as db:
        u = _resolve_user(db, uid)
        return _user_row_to_record(u) if u else None


def get_user_by_email(email: str) -> UserRecord | None:
    with _session() as db:
        u = db.query(User).filter(User.email == email).limit(1).first()
        return _user_row_to_record(u) if u else None


def list_users() -> list[UserRecord]:
    with _session() as db:
        rows = db.query(User).order_by(User.created_at.desc()).all()
        return [_user_row_to_record(u) for u in rows]


def upsert_user(
    uid: str,
    *,
    email: str,
    display_name: str | None,
    role: str,
    disabled: bool = False,
    phone: str | None = None,
    district: str | None = None,
) -> UserRecord:
    with _session() as db:
        u = _resolve_user(db, uid)
        if u is None:
            u = User(firebase_uid=uid, email=email, display_name=display_name, role=role, disabled=disabled)
            db.add(u)
        else:
            u.email = email
            u.display_name = display_name
            u.role = role
            u.disabled = disabled
        if phone is not None:
            u.phone = phone
        if district is not None:
            u.district = district
        db.commit()
        db.refresh(u)
        return _user_row_to_record(u)


def update_user(uid: str, **fields: Any) -> UserRecord | None:
    with _session() as db:
        u = _resolve_user(db, uid)
        if u is None:
            return None
        for key, val in fields.items():
            if hasattr(u, key):
                setattr(u, key, val)
        db.commit()
        db.refresh(u)
        return _user_row_to_record(u)


def delete_user(uid: str) -> bool:
    with _session() as db:
        u = _resolve_user(db, uid)
        if u is None:
            return False
        db.delete(u)
        db.commit()
        return True


def create_prediction(uid: str, data: dict[str, Any]) -> str:
    with _session() as db:
        u = _resolve_user(db, uid)
        if u is None:
            raise ValueError("User not found")
        ranking = data.get("full_ranking") or []
        row = CropPrediction(
            user_id=u.id,
            nitrogen=float(data.get("nitrogen", 0)),
            phosphorus=float(data.get("phosphorus", 0)),
            potassium=float(data.get("potassium", 0)),
            soil_moisture=float(data.get("soil_moisture", 0)),
            temperature_c=float(data.get("temperature_c", 0)),
            humidity_pct=float(data.get("humidity_pct", 0)),
            soil_ph=float(data.get("soil_ph", 0)),
            rainfall_mm=float(data.get("rainfall_mm", 0)),
            model_version=str(data.get("model_version", "")),
            top_crop=str(data.get("top_crop", "")),
            top_confidence=float(data.get("top_confidence", 0)),
            explanation=str(data.get("explanation", "")),
            full_ranking_json=json.dumps({"full_ranking": ranking, **{k: data[k] for k in data if k not in {
                "nitrogen", "phosphorus", "potassium", "soil_moisture", "temperature_c", "humidity_pct",
                "soil_ph", "rainfall_mm", "model_version", "top_crop", "top_confidence", "explanation", "full_ranking",
            }}}),
        )
        db.add(row)
        db.commit()
        db.refresh(row)
        return str(row.id)


def _prediction_to_row(p: CropPrediction, uid: str) -> dict[str, Any]:
    extra: dict[str, Any] = {}
    try:
        extra = json.loads(p.full_ranking_json) if p.full_ranking_json else {}
    except json.JSONDecodeError:
        extra = {}
    if not isinstance(extra, dict):
        extra = {}
    ranking = extra.pop("full_ranking", [])
    row = {
        "id": str(p.id),
        "user_uid": uid,
        "nitrogen": p.nitrogen,
        "phosphorus": p.phosphorus,
        "potassium": p.potassium,
        "soil_moisture": p.soil_moisture,
        "temperature_c": p.temperature_c,
        "humidity_pct": p.humidity_pct,
        "soil_ph": p.soil_ph,
        "rainfall_mm": p.rainfall_mm,
        "model_version": p.model_version,
        "top_crop": p.top_crop,
        "top_confidence": p.top_confidence,
        "explanation": p.explanation,
        "full_ranking": ranking,
        "created_at": p.created_at,
        **extra,
    }
    return row


def list_predictions_for_user(uid: str, limit: int = 30) -> list[dict[str, Any]]:
    with _session() as db:
        u = _resolve_user(db, uid)
        if u is None:
            return []
        rows = (
            db.query(CropPrediction)
            .filter(CropPrediction.user_id == u.id)
            .order_by(CropPrediction.created_at.desc())
            .limit(limit)
            .all()
        )
        return [_prediction_to_row(p, uid) for p in rows]


def count_predictions() -> int:
    with _session() as db:
        return db.query(CropPrediction).count()


def crop_distribution() -> dict[str, int]:
    counts: dict[str, int] = {}
    with _session() as db:
        for (crop,) in db.query(CropPrediction.top_crop).all():
            key = str(crop or "").strip().lower()
            if key:
                counts[key] = counts.get(key, 0) + 1
    return dict(sorted(counts.items(), key=lambda x: -x[1]))


def list_recent_predictions(limit: int = 20) -> list[dict[str, Any]]:
    with _session() as db:
        rows = (
            db.query(CropPrediction, User.firebase_uid)
            .join(User, CropPrediction.user_id == User.id)
            .order_by(CropPrediction.created_at.desc())
            .limit(min(limit, 50))
            .all()
        )
        return [_prediction_to_row(p, uid) for p, uid in rows]


def count_farmers() -> int:
    with _session() as db:
        return db.query(User).filter(User.role == "farmer").count()


def count_active_farmers() -> int:
    with _session() as db:
        return db.query(User).filter(User.role == "farmer", User.disabled.is_(False)).count()


def count_disabled_farmers() -> int:
    return count_farmers() - count_active_farmers()


def prediction_counts_by_user() -> dict[str, int]:
    counts: dict[str, int] = {}
    with _session() as db:
        for p, uid in db.query(CropPrediction, User.firebase_uid).join(User).all():
            counts[uid] = counts.get(uid, 0) + 1
    return counts


def prediction_count_for_user(uid: str) -> int:
    with _session() as db:
        u = _resolve_user(db, uid)
        if u is None:
            return 0
        return db.query(CropPrediction).filter(CropPrediction.user_id == u.id).count()


def log_activity(**kwargs: Any) -> str:
    return str(uuid.uuid4())


def list_activity_logs(limit: int = 40) -> list[dict[str, Any]]:
    return []


def create_notification(**kwargs: Any) -> str:
    return str(uuid.uuid4())


def list_notifications(limit: int = 30) -> list[dict[str, Any]]:
    return []


def mark_notification_read(doc_id: str) -> bool:
    return False


def delete_dataset(doc_id: str) -> bool:
    with _session() as db:
        row = db.get(TrainingDataset, int(doc_id)) if doc_id.isdigit() else None
        if row is None:
            return False
        db.delete(row)
        db.commit()
        return True


def update_dataset(doc_id: str, **fields: Any) -> dict[str, Any] | None:
    with _session() as db:
        row = db.get(TrainingDataset, int(doc_id)) if doc_id.isdigit() else None
        if row is None:
            return None
        for k, v in fields.items():
            if hasattr(row, k):
                setattr(row, k, v)
        db.commit()
        return get_dataset(doc_id)


def list_datasets() -> list[dict[str, Any]]:
    with _session() as db:
        rows = db.query(TrainingDataset).order_by(TrainingDataset.created_at.desc()).all()
        return [
            {
                "id": str(r.id),
                "name": r.name,
                "filename": r.filename,
                "row_count": r.row_count,
                "is_active": r.is_active,
                "created_at": r.created_at,
            }
            for r in rows
        ]


def create_dataset(data: dict[str, Any]) -> str:
    with _session() as db:
        row = TrainingDataset(
            name=data.get("name", "dataset"),
            filename=data.get("filename", ""),
            row_count=int(data.get("row_count", 0)),
            is_active=bool(data.get("is_active", False)),
        )
        db.add(row)
        db.commit()
        db.refresh(row)
        return str(row.id)


def get_dataset(doc_id: str) -> dict[str, Any] | None:
    with _session() as db:
        if not doc_id.isdigit():
            return None
        r = db.get(TrainingDataset, int(doc_id))
        if r is None:
            return None
        return {
            "id": str(r.id),
            "name": r.name,
            "filename": r.filename,
            "row_count": r.row_count,
            "is_active": r.is_active,
            "created_at": r.created_at,
        }


def set_active_dataset(doc_id: str) -> None:
    with _session() as db:
        for r in db.query(TrainingDataset).all():
            r.is_active = str(r.id) == doc_id
        db.commit()


def count_datasets() -> int:
    with _session() as db:
        return db.query(TrainingDataset).count()


_model_meta: dict[str, Any] | None = None


def save_model_meta(meta: dict[str, Any]) -> None:
    global _model_meta
    _model_meta = meta


def get_model_meta() -> dict[str, Any] | None:
    if _model_meta is not None:
        return _model_meta
    from app.ml_service import META_PATH
    import json as _json
    from pathlib import Path

    path = Path(META_PATH)
    if path.is_file():
        return _json.loads(path.read_text(encoding="utf-8"))
    return None


def list_farmer_tips(limit: int = 10) -> list[dict[str, Any]]:
    return []


def get_prediction(doc_id: str, user_uid: str) -> dict[str, Any] | None:
    row = get_prediction_by_id(doc_id)
    if row is None or row.get("user_uid") != user_uid:
        return None
    return row


def get_prediction_by_id(doc_id: str) -> dict[str, Any] | None:
    if not doc_id.isdigit():
        return None
    with _session() as db:
        p = db.get(CropPrediction, int(doc_id))
        if p is None:
            return None
        u = db.get(User, p.user_id)
        uid = u.firebase_uid if u else ""
        return _prediction_to_row(p, uid)


def fertilizer_usage_stats() -> dict[str, int]:
    return {}


def avg_soil_health_score() -> float:
    scores: list[float] = []
    with _session() as db:
        for p in db.query(CropPrediction).all():
            try:
                extra = json.loads(p.full_ranking_json or "{}")
                v = extra.get("soil_health_score")
                if v is not None:
                    scores.append(float(v))
            except (json.JSONDecodeError, TypeError, ValueError):
                pass
    if not scores:
        return 0.0
    return round(sum(scores) / len(scores), 1)


def create_outcome_feedback(user_uid: str, **kwargs: Any) -> str:
    return str(uuid.uuid4())


def get_feedback_for_prediction(prediction_id: str, user_uid: str) -> dict[str, Any] | None:
    return None


def list_outcome_feedback_for_user(user_uid: str, limit: int = 30) -> list[dict[str, Any]]:
    return []


def outcome_analytics() -> dict[str, Any]:
    return {
        "outcome_feedback_count": 0,
        "avg_outcome_rating": None,
        "fertilizer_follow_rate_pct": None,
    }
