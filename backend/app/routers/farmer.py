from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException

from app.deps import require_farmer
from app.firestore_db import (
    UserRecord,
    create_outcome_feedback,
    get_feedback_for_prediction,
    get_prediction,
    list_farmer_tips,
    list_outcome_feedback_for_user,
)
from app.schemas import FarmerTipItem, OutcomeFeedbackItem, OutcomeFeedbackRequest

router = APIRouter(prefix="/farmer", tags=["farmer"])

_DEFAULT_TIPS = [
    {
        "id": "tip-1",
        "title": "Soil testing",
        "message": "Test N, P, K and pH every season — accurate readings improve crop and fertilizer AI recommendations.",
        "category": "tip",
    },
    {
        "id": "tip-2",
        "title": "Right fertilizer, right time",
        "message": "Split nitrogen applications and match phosphorus to planting to reduce runoff and save costs.",
        "category": "fertilizer",
    },
    {
        "id": "tip-3",
        "title": "Season-aware planting",
        "message": "Use Season A/B/C guidance with live Open-Meteo forecasts — avoid excess fertilizer in dry Season C.",
        "category": "crop",
    },
    {
        "id": "tip-4",
        "title": "Precision agriculture",
        "message": "Rate your harvest outcomes in the app — your feedback helps improve recommendations over time.",
        "category": "system",
    },
]


def _ts(value) -> datetime | None:
    if value is None:
        return None
    if hasattr(value, "timestamp"):
        return datetime.fromtimestamp(value.timestamp(), tz=timezone.utc)
    return value


@router.get("/tips", response_model=list[FarmerTipItem])
def farmer_tips(_: UserRecord = Depends(require_farmer)):
    rows = list_farmer_tips()
    if not rows:
        return [FarmerTipItem(**t) for t in _DEFAULT_TIPS]
    items = []
    for row in rows:
        items.append(
            FarmerTipItem(
                id=row["id"],
                title=row.get("title", "Farming tip"),
                message=row.get("message", ""),
                category=row.get("category", "tip"),
            )
        )
    return items


@router.post("/feedback", response_model=OutcomeFeedbackItem)
def submit_outcome_feedback(
    payload: OutcomeFeedbackRequest,
    user: UserRecord = Depends(require_farmer),
):
    pred = get_prediction(payload.prediction_id, user.uid)
    if pred is None:
        raise HTTPException(status_code=404, detail="Prediction not found")

    crop_grown = (payload.crop_grown or pred.get("top_crop", "")).strip()
    try:
        fid = create_outcome_feedback(
            user.uid,
            prediction_id=payload.prediction_id,
            recommended_crop=str(pred.get("top_crop", "")),
            yield_rating=payload.yield_rating,
            crop_grown=crop_grown or None,
            followed_fertilizer=payload.followed_fertilizer,
            notes=payload.notes,
        )
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e)) from e

    return OutcomeFeedbackItem(
        id=fid,
        prediction_id=payload.prediction_id,
        recommended_crop=str(pred.get("top_crop", "")),
        crop_grown=crop_grown or None,
        yield_rating=payload.yield_rating,
        followed_fertilizer=payload.followed_fertilizer,
        notes=payload.notes,
        created_at=datetime.now(timezone.utc),
    )


@router.get("/feedback", response_model=list[OutcomeFeedbackItem])
def list_my_feedback(limit: int = 30, user: UserRecord = Depends(require_farmer)):
    rows = list_outcome_feedback_for_user(user.uid, limit=min(limit, 50))
    return [
        OutcomeFeedbackItem(
            id=r["id"],
            prediction_id=str(r.get("prediction_id", "")),
            recommended_crop=str(r.get("recommended_crop", "")),
            crop_grown=r.get("crop_grown"),
            yield_rating=int(r.get("yield_rating", 0)),
            followed_fertilizer=bool(r.get("followed_fertilizer", False)),
            notes=r.get("notes") or None,
            created_at=_ts(r.get("created_at")),
        )
        for r in rows
    ]


@router.get("/feedback/{prediction_id}", response_model=OutcomeFeedbackItem | None)
def get_feedback_for_prediction_route(
    prediction_id: str,
    user: UserRecord = Depends(require_farmer),
):
    row = get_feedback_for_prediction(prediction_id, user.uid)
    if row is None:
        return None
    return OutcomeFeedbackItem(
        id=row["id"],
        prediction_id=str(row.get("prediction_id", "")),
        recommended_crop=str(row.get("recommended_crop", "")),
        crop_grown=row.get("crop_grown"),
        yield_rating=int(row.get("yield_rating", 0)),
        followed_fertilizer=bool(row.get("followed_fertilizer", False)),
        notes=row.get("notes") or None,
        created_at=_ts(row.get("created_at")),
    )
