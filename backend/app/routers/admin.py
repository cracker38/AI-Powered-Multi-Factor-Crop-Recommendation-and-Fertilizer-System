import shutil
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path

import pandas as pd
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from fastapi.responses import PlainTextResponse

from app.deps import require_admin
from app.farm_improvement import build_improvement_actions
from app.fertilizer_service import recommend_fertilizers, soil_health_assessment
from app.ml_service import predict_ranked
from app.rwanda_season import current_rwanda_season, season_label
from app.firestore_timeout import run_firestore
from app.firebase_app import delete_firebase_user, disable_firebase_user
from app.firestore_db import (
    UserRecord,
    count_active_farmers,
    count_datasets,
    count_disabled_farmers,
    count_farmers,
    count_predictions,
    create_dataset,
    create_prediction,
    create_notification,
    avg_soil_health_score,
    crop_distribution,
    fertilizer_usage_stats,
    outcome_analytics,
    delete_dataset,
    delete_user,
    get_dataset,
    get_model_meta,
    get_prediction_by_id,
    get_user,
    list_activity_logs,
    list_datasets,
    list_notifications,
    list_recent_predictions,
    list_users,
    log_activity,
    mark_notification_read,
    prediction_count_for_user,
    prediction_counts_by_user,
    save_model_meta,
    set_active_dataset,
    update_dataset,
    update_user,
)
from app.ml_service import META_PATH, MODEL_PATH, _load_meta
from app.schemas import (
    ActivityLogItem,
    AdminApproveFarmerRequest,
    AdminPredictionItem,
    AdminUserItem,
    AdminUserUpdate,
    DatasetItem,
    DatasetUpdate,
    ModelReportResponse,
    ModelStatusResponse,
    NotificationItem,
    TrainModelResponse,
)
from app.user_profile_utils import user_to_profile
from app.weather_service import apply_live_climate
from app.weather_service import weather_insight as build_weather_insight

router = APIRouter(prefix="/admin", tags=["admin"])

DATASETS_DIR = Path(__file__).resolve().parent.parent.parent / "models" / "datasets"
ACTIVE_LINK = Path(__file__).resolve().parent.parent.parent / "models" / "active_dataset.csv"
REQUIRED_COLS = {"N", "P", "K", "soil_moisture", "temperature", "humidity", "ph", "rainfall", "label"}


def _ts(value) -> datetime:
    if value is None:
        return datetime.now(timezone.utc)
    if hasattr(value, "timestamp"):
        return datetime.fromtimestamp(value.timestamp(), tz=timezone.utc)
    return value


def _model_metrics(meta: dict | None) -> tuple[float | None, float | None, float | None, float | None]:
    if not meta:
        return None, None, None, None
    best = meta.get("best_model")
    if not best:
        return None, None, None, None
    m = (meta.get("all_metrics") or {}).get(best) or {}
    return (
        m.get("accuracy"),
        m.get("precision_weighted"),
        m.get("recall_weighted"),
        m.get("f1_weighted"),
    )


def _user_item(user: UserRecord, pred_counts: dict[str, int] | None = None) -> AdminUserItem:
    counts = pred_counts or {}
    profile = user_to_profile(user)
    return AdminUserItem(
        id=user.uid,
        email=user.email,
        display_name=user.display_name,
        role=user.role,
        disabled=user.disabled,
        created_at=user.created_at or datetime.now(timezone.utc),
        prediction_count=counts.get(user.uid, prediction_count_for_user(user.uid)),
        phone=user.phone,
        district=user.district,
        farm_size_ha=user.farm_size_ha,
        approval_status=profile.approval_status,
        field_data=profile.field_data,
    )


def _prediction_item(row: dict, farmer: UserRecord | None = None) -> AdminPredictionItem:
    return AdminPredictionItem(
        id=row["id"],
        user_uid=str(row.get("user_uid", "")),
        top_crop=str(row.get("top_crop", "")),
        top_confidence=float(row.get("top_confidence", 0)),
        model_version=str(row.get("model_version", "")),
        created_at=_ts(row.get("created_at")),
        farmer_email=farmer.email if farmer else None,
        farmer_name=farmer.display_name if farmer else None,
        district=row.get("district"),
        season=row.get("season"),
        soil_type=row.get("soil_type"),
        soil_health_score=float(row.get("soil_health_score", 0) or 0),
        soil_ph=float(row["soil_ph"]) if row.get("soil_ph") is not None else None,
        nitrogen=float(row["nitrogen"]) if row.get("nitrogen") is not None else None,
        phosphorus=float(row["phosphorus"]) if row.get("phosphorus") is not None else None,
        potassium=float(row["potassium"]) if row.get("potassium") is not None else None,
    )


def _audit(admin: UserRecord, action: str, category: str, detail: str = "", severity: str = "info") -> None:
    log_activity(
        actor_uid=admin.uid,
        actor_email=admin.email,
        action=action,
        category=category,
        detail=detail,
        severity=severity,
    )


def _read_uploaded_table(content: bytes, filename: str) -> pd.DataFrame:
    lower = filename.lower()
    if lower.endswith(".csv"):
        return pd.read_csv(BytesIO(content))
    if lower.endswith((".xlsx", ".xls")):
        return pd.read_excel(BytesIO(content))
    raise HTTPException(status_code=400, detail="Upload CSV or Excel (.xlsx) file")


def _validate_dataset_df(df: pd.DataFrame) -> pd.DataFrame:
    if not REQUIRED_COLS.issubset(set(df.columns)):
        raise HTTPException(
            status_code=400,
            detail=f"File must include columns: {sorted(REQUIRED_COLS)}",
        )
    for c in REQUIRED_COLS:
        if c != "label":
            df[c] = pd.to_numeric(df[c], errors="coerce")
    return df.dropna()


@router.get("/users", response_model=list[AdminUserItem])
def list_users_route(_: UserRecord = Depends(require_admin)):
    pred_counts = prediction_counts_by_user()
    return [_user_item(u, pred_counts) for u in list_users()]


@router.get("/users/{user_id}", response_model=AdminUserItem)
def get_user_route(user_id: str, _: UserRecord = Depends(require_admin)):
    user = get_user(user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return _user_item(user)


@router.post("/users/{user_id}/approve", response_model=AdminUserItem)
def approve_farmer_route(
    user_id: str,
    body: AdminApproveFarmerRequest,
    admin: UserRecord = Depends(require_admin),
):
    user = get_user(user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role != "farmer":
        raise HTTPException(status_code=400, detail="Only farmer accounts can be approved")
    if user.approval_status == "approved":
        raise HTTPException(status_code=400, detail="Farmer already approved")

    fd = body.field_data
    temp, hum, rain, _ = apply_live_climate(
        district=body.district or user.district,
        temperature_c=fd.temperature_c,
        humidity_pct=fd.humidity_pct,
        rainfall_mm=fd.rainfall_mm,
    )
    field_data = fd.model_copy(
        update={"temperature_c": temp, "humidity_pct": hum, "rainfall_mm": rain}
    ).model_dump()

    season = current_rwanda_season()
    ranked, explanation, ml_info = predict_ranked(
        nitrogen=field_data["nitrogen"],
        phosphorus=field_data["phosphorus"],
        potassium=field_data["potassium"],
        soil_moisture=field_data["soil_moisture"],
        temperature_c=field_data["temperature_c"],
        humidity_pct=field_data["humidity_pct"],
        soil_ph=field_data["soil_ph"],
        rainfall_mm=field_data["rainfall_mm"],
        soil_type=field_data["soil_type"],
        season=season,
        district=body.district or user.district,
    )
    top_crop = ranked[0][0]
    soil_health_score, soil_health_label = soil_health_assessment(
        field_data["nitrogen"],
        field_data["phosphorus"],
        field_data["potassium"],
        field_data["soil_ph"],
        field_data["soil_moisture"],
    )
    fert_raw, nutrient_analysis, fert_notes = recommend_fertilizers(
        crop=top_crop,
        nitrogen=field_data["nitrogen"],
        phosphorus=field_data["phosphorus"],
        potassium=field_data["potassium"],
        soil_ph=field_data["soil_ph"],
        soil_moisture=field_data["soil_moisture"],
        soil_type=field_data["soil_type"],
        season=season,
        district=body.district or user.district,
    )
    precision_notes = list(ml_info.get("precision_notes_adss") or [])
    if ml_info.get("fertilizer_applicable", True):
        precision_notes.extend(fert_notes)
    weather_insight = build_weather_insight(
        season=season,
        district=body.district or user.district,
        rainfall_mm=field_data["rainfall_mm"],
        temperature_c=field_data["temperature_c"],
        humidity_pct=field_data["humidity_pct"],
    )
    improvement_actions = build_improvement_actions(
        ranked[0][1],
        top_crop,
        nitrogen=field_data["nitrogen"],
        phosphorus=field_data["phosphorus"],
        potassium=field_data["potassium"],
        soil_moisture=field_data["soil_moisture"],
        temperature_c=field_data["temperature_c"],
        humidity_pct=field_data["humidity_pct"],
        soil_ph=field_data["soil_ph"],
        rainfall_mm=field_data["rainfall_mm"],
        soil_type=field_data["soil_type"],
        season=season,
        soil_health_score=soil_health_score,
    )

    updated = update_user(
        user_id,
        display_name=body.display_name,
        phone=body.phone,
        district=body.district,
        farm_size_ha=body.farm_size_ha,
        field_data=field_data,
        approval_status="approved",
        disabled=False,
    )
    create_prediction(
        user.uid,
        {
            "nitrogen": field_data["nitrogen"],
            "phosphorus": field_data["phosphorus"],
            "potassium": field_data["potassium"],
            "soil_moisture": field_data["soil_moisture"],
            "temperature_c": field_data["temperature_c"],
            "humidity_pct": field_data["humidity_pct"],
            "soil_ph": field_data["soil_ph"],
            "rainfall_mm": field_data["rainfall_mm"],
            "soil_type": field_data["soil_type"],
            "season": season,
            "district": body.district or user.district,
            "model_version": str(ml_info.get("model_version", "unknown")),
            "top_crop": top_crop,
            "top_confidence": ranked[0][1],
            "explanation": explanation,
            "full_ranking": [{"crop": n, "confidence": s} for n, s in ranked],
            "soil_health_score": soil_health_score,
            "soil_health_label": soil_health_label,
            "fertilizers": fert_raw,
            "nutrient_analysis": nutrient_analysis,
            "weather_insight": weather_insight,
            "precision_notes": precision_notes,
            "environment_analysis": list(ml_info.get("environment_analysis") or []),
            "season_used": season,
            "season_label": season_label(season),
            "improvement_actions": improvement_actions,
        },
    )
    create_notification(
        title="Farmer account approved",
        message=f"{body.display_name} ({user.email}) was approved and can now run crop analyses.",
        category="user",
        severity="info",
    )
    _audit(
        admin,
        "farmer_approved",
        "user",
        f"{user.email} — {body.farm_size_ha} ha"
        + (f" — notes: {body.admin_notes}" if body.admin_notes else ""),
    )
    return _user_item(updated)  # type: ignore[arg-type]


@router.post("/users/{user_id}/reject", response_model=AdminUserItem)
def reject_farmer_route(user_id: str, admin: UserRecord = Depends(require_admin)):
    user = get_user(user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role != "farmer":
        raise HTTPException(status_code=400, detail="Only farmer accounts can be rejected")
    updated = update_user(user_id, approval_status="rejected", disabled=True)
    try:
        disable_firebase_user(user.uid, True)
    except Exception:
        pass
    _audit(admin, "farmer_rejected", "user", user.email, severity="warning")
    return _user_item(updated)  # type: ignore[arg-type]


@router.patch("/users/{user_id}", response_model=AdminUserItem)
def update_user_route(
    user_id: str,
    body: AdminUserUpdate,
    admin: UserRecord = Depends(require_admin),
):
    user = get_user(user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role == "admin" and user.uid != admin.uid:
        raise HTTPException(status_code=403, detail="Cannot modify other admin accounts")
    if user.role == "admin" and body.disabled is True:
        raise HTTPException(status_code=403, detail="Cannot disable admin account")

    updates = {}
    if body.display_name is not None:
        updates["display_name"] = body.display_name
    if body.disabled is not None:
        updates["disabled"] = body.disabled
        try:
            disable_firebase_user(user.uid, body.disabled)
        except Exception as exc:
            raise HTTPException(
                status_code=502,
                detail=f"Could not update sign-in access: {exc}",
            ) from exc
    user = update_user(user_id, **updates)
    _audit(
        admin,
        "user_updated",
        "user",
        f"{user.email}: display_name={body.display_name}, disabled={body.disabled}",
    )
    if body.disabled is True:
        create_notification(
            title="Account disabled",
            message=f"Farmer {user.email} was disabled by admin.",
            category="security",
            severity="warning",
        )
    return _user_item(user)


@router.delete("/users/{user_id}")
def delete_user_route(user_id: str, admin: UserRecord = Depends(require_admin)):
    user = get_user(user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role == "admin":
        raise HTTPException(status_code=403, detail="Cannot delete admin account")
    try:
        disable_firebase_user(user.uid, True)
    except Exception:
        pass
    delete_user(user_id)
    try:
        delete_firebase_user(user.uid)
    except Exception:
        pass
    _audit(admin, "user_deleted", "user", user.email, severity="warning")
    create_notification(
        title="Account deleted",
        message=f"Farmer account {user.email} was removed.",
        category="security",
        severity="warning",
    )
    return {"ok": True}


@router.get("/datasets", response_model=list[DatasetItem])
def list_datasets_route(_: UserRecord = Depends(require_admin)):
    items = []
    for d in list_datasets():
        items.append(
            DatasetItem(
                id=d["id"],
                name=d.get("name", ""),
                filename=d.get("filename", ""),
                row_count=int(d.get("row_count", 0)),
                is_active=bool(d.get("is_active", False)),
                created_at=_ts(d.get("created_at")),
            )
        )
    return items


@router.patch("/datasets/{dataset_id}", response_model=DatasetItem)
def update_dataset_route(
    dataset_id: str,
    body: DatasetUpdate,
    admin: UserRecord = Depends(require_admin),
):
    ds = update_dataset(dataset_id, name=body.name)
    if ds is None:
        raise HTTPException(status_code=404, detail="Dataset not found")
    _audit(admin, "dataset_updated", "dataset", f"Renamed to {body.name}")
    return DatasetItem(
        id=ds["id"],
        name=ds.get("name", ""),
        filename=ds.get("filename", ""),
        row_count=int(ds.get("row_count", 0)),
        is_active=bool(ds.get("is_active", False)),
        created_at=_ts(ds.get("created_at")),
    )


@router.delete("/datasets/{dataset_id}")
def delete_dataset_route(dataset_id: str, admin: UserRecord = Depends(require_admin)):
    ds = get_dataset(dataset_id)
    if ds is None:
        raise HTTPException(status_code=404, detail="Dataset not found")
    if ds.get("is_active"):
        raise HTTPException(status_code=400, detail="Cannot delete the active dataset. Activate another first.")
    fname = ds.get("filename", "")
    src = DATASETS_DIR / fname
    if src.exists():
        src.unlink()
    delete_dataset(dataset_id)
    _audit(admin, "dataset_deleted", "dataset", fname)
    return {"ok": True}


@router.post("/datasets/upload", response_model=DatasetItem)
async def upload_dataset(
    name: str = Form(...),
    file: UploadFile = File(...),
    admin: UserRecord = Depends(require_admin),
):
    if not file.filename:
        raise HTTPException(status_code=400, detail="Filename required")
    lower = file.filename.lower()
    if not lower.endswith((".csv", ".xlsx", ".xls")):
        raise HTTPException(status_code=400, detail="CSV or Excel (.xlsx) file required")

    DATASETS_DIR.mkdir(parents=True, exist_ok=True)
    content = await file.read()
    try:
        df = _validate_dataset_df(_read_uploaded_table(content, file.filename))
        row_count = len(df)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid file: {e}") from e

    save_name = file.filename if lower.endswith(".csv") else f"{Path(file.filename).stem}.csv"
    dest = DATASETS_DIR / save_name
    df.to_csv(dest, index=False)

    doc_id = create_dataset(
        {
            "name": name,
            "filename": save_name,
            "row_count": row_count,
            "uploaded_by_uid": admin.uid,
            "is_active": False,
        }
    )
    _audit(admin, "dataset_uploaded", "dataset", f"{name} ({row_count} rows)")
    create_notification(
        title="Dataset uploaded",
        message=f'"{name}" with {row_count} rows is ready. Activate it for training.',
        category="dataset",
        severity="info",
    )
    d = get_dataset(doc_id)
    return DatasetItem(
        id=doc_id,
        name=name,
        filename=save_name,
        row_count=row_count,
        is_active=False,
        created_at=_ts(d.get("created_at") if d else None),
    )


@router.post("/datasets/{dataset_id}/activate")
def activate_dataset(dataset_id: str, admin: UserRecord = Depends(require_admin)):
    ds = get_dataset(dataset_id)
    if ds is None:
        raise HTTPException(status_code=404, detail="Dataset not found")
    src = DATASETS_DIR / ds["filename"]
    if not src.exists():
        raise HTTPException(status_code=404, detail="Dataset file missing on disk")
    ACTIVE_LINK.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, ACTIVE_LINK)
    set_active_dataset(dataset_id)
    _audit(admin, "dataset_activated", "dataset", ds.get("name", dataset_id))
    return {"ok": True, "active_dataset_id": dataset_id}


@router.post("/model/train", response_model=TrainModelResponse)
def train_model(admin: UserRecord = Depends(require_admin)):
    import sys

    root = Path(__file__).resolve().parent.parent.parent.parent
    if str(root) not in sys.path:
        sys.path.insert(0, str(root))
    from ml.train import main as train_main

    try:
        train_main()
        meta = _load_meta()
        save_model_meta(meta)
        best = meta.get("best_model", "unknown")
        metrics = (meta.get("all_metrics") or {}).get(best, {})
        acc = float(metrics.get("accuracy", 0.0))
        prec = float(metrics.get("precision_weighted", 0.0))
        rec = float(metrics.get("recall_weighted", 0.0))
        f1 = float(metrics.get("f1_weighted", 0.0))
        _audit(
            admin,
            "model_trained",
            "model",
            f"{best} accuracy={acc:.2%}",
        )
        create_notification(
            title="Model training complete",
            message=f"{best} deployed with {acc:.1%} accuracy.",
            category="model",
            severity="info",
        )
        return TrainModelResponse(
            success=True,
            best_model=best,
            accuracy=acc,
            precision=prec,
            recall=rec,
            f1=f1,
            message="Model trained and deployed successfully.",
        )
    except Exception as e:
        _audit(admin, "model_train_failed", "model", str(e), severity="error")
        create_notification(
            title="Model training failed",
            message=str(e),
            category="model",
            severity="error",
        )
        raise HTTPException(status_code=500, detail=str(e)) from e


@router.get("/model/report", response_model=ModelReportResponse)
def model_report(_: UserRecord = Depends(require_admin)):
    loaded = MODEL_PATH.exists()
    meta = _load_meta() if loaded else get_model_meta()
    report = None
    if meta and META_PATH.exists():
        best = meta.get("best_model")
        lines = [f"Best model: {best}", ""]
        for name, m in (meta.get("all_metrics") or {}).items():
            lines.append(
                f"{name}: acc={m.get('accuracy', 0):.4f} "
                f"prec={m.get('precision_weighted', 0):.4f} "
                f"rec={m.get('recall_weighted', 0):.4f}"
            )
        report = "\n".join(lines)
    return ModelReportResponse(
        model_loaded=loaded,
        model_version=meta.get("best_model") if meta else None,
        meta=meta,
        training_report_text=report,
    )


@router.get("/model/report/download")
def download_model_report(_: UserRecord = Depends(require_admin)):
    meta = _load_meta() if MODEL_PATH.exists() else get_model_meta()
    if not meta:
        raise HTTPException(status_code=404, detail="No training report available")
    import json

    return PlainTextResponse(
        json.dumps(meta, indent=2),
        media_type="text/plain",
        headers={"Content-Disposition": 'attachment; filename="training_report.json"'},
    )


@router.get("/predictions", response_model=list[AdminPredictionItem])
def list_predictions_route(limit: int = 15, _: UserRecord = Depends(require_admin)):
    users_by_uid = {u.uid: u for u in list_users()}
    return [
        _prediction_item(row, users_by_uid.get(str(row.get("user_uid", ""))))
        for row in list_recent_predictions(limit=min(limit, 50))
    ]


@router.get("/predictions/{prediction_id}", response_model=AdminPredictionItem)
def get_prediction_route(prediction_id: str, _: UserRecord = Depends(require_admin)):
    row = get_prediction_by_id(prediction_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Prediction not found")
    uid = str(row.get("user_uid", ""))
    farmer = get_user(uid)
    return _prediction_item(row, farmer)


@router.get("/activity-logs", response_model=list[ActivityLogItem])
def activity_logs_route(limit: int = 30, _: UserRecord = Depends(require_admin)):
    items = []
    for row in list_activity_logs(limit=min(limit, 100)):
        items.append(
            ActivityLogItem(
                id=row["id"],
                actor_uid=row.get("actor_uid", ""),
                actor_email=row.get("actor_email", ""),
                action=row.get("action", ""),
                category=row.get("category", "system"),
                detail=row.get("detail", ""),
                severity=row.get("severity", "info"),
                created_at=_ts(row.get("created_at")),
            )
        )
    return items


@router.get("/notifications", response_model=list[NotificationItem])
def notifications_route(limit: int = 25, _: UserRecord = Depends(require_admin)):
    items = []
    for row in list_notifications(limit=min(limit, 50)):
        items.append(
            NotificationItem(
                id=row["id"],
                title=row.get("title", ""),
                message=row.get("message", ""),
                category=row.get("category", "system"),
                severity=row.get("severity", "info"),
                read=bool(row.get("read", False)),
                created_at=_ts(row.get("created_at")),
            )
        )
    return items


@router.patch("/notifications/{notification_id}/read")
def mark_notification_read_route(notification_id: str, _: UserRecord = Depends(require_admin)):
    if not mark_notification_read(notification_id):
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"ok": True}


@router.get("/analytics", response_model=ModelStatusResponse)
def analytics(_: UserRecord = Depends(require_admin)):
    def _build() -> ModelStatusResponse:
        loaded = MODEL_PATH.exists()
        meta = _load_meta() if loaded else get_model_meta()
        farmers = count_farmers()
        preds = count_predictions()
        acc, prec, rec, f1 = _model_metrics(meta)
        last_trained = None
        if meta and meta.get("updated_at"):
            last_trained = _ts(meta.get("updated_at"))
        elif get_model_meta():
            last_trained = _ts(get_model_meta().get("updated_at"))

        outcomes = outcome_analytics()
        return ModelStatusResponse(
            model_loaded=loaded,
            model_version=meta.get("best_model") if meta else None,
            meta=meta,
            training_datasets_count=count_datasets(),
            total_predictions=preds,
            total_farmers=farmers,
            active_farmers=count_active_farmers(),
            disabled_farmers=count_disabled_farmers(),
            avg_predictions_per_farmer=round(preds / farmers, 2) if farmers else 0.0,
            crop_distribution=crop_distribution(),
            model_accuracy=float(acc) if acc is not None else None,
            model_precision=float(prec) if prec is not None else None,
            model_recall=float(rec) if rec is not None else None,
            model_f1=float(f1) if f1 is not None else None,
            last_trained_at=last_trained,
            fertilizer_usage=fertilizer_usage_stats(),
            avg_soil_health_score=avg_soil_health_score(),
            outcome_feedback_count=outcomes.get("outcome_feedback_count", 0),
            avg_outcome_rating=outcomes.get("avg_outcome_rating"),
            fertilizer_follow_rate_pct=outcomes.get("fertilizer_follow_rate_pct"),
        )

    return run_firestore("analytics dashboard", _build, timeout_sec=20.0)
