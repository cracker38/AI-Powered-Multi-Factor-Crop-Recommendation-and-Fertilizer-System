from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException

from app.deps import require_approved_farmer, require_farmer
from app.farm_improvement import build_improvement_actions
from app.farmer_plan_service import build_and_save_farmer_plan
from app.fertilizer_service import recommend_fertilizers, soil_health_assessment
from app.firestore_db import (
    UserRecord,
    create_prediction,
    get_feedback_for_prediction,
    get_prediction,
    list_predictions_for_user,
)
from app.ml_service import predict_ranked
from app.rwanda_season import current_rwanda_season, season_label
from app.schemas import (
    CropPredictionResponse,
    CropRankItem,
    FarmConditionsRequest,
    FertilizerRecommendationItem,
    ForecastDayItem,
    NutrientAnalysis,
    PredictionDetailItem,
    PredictionHistoryItem,
    WeatherInsight,
)
from app.weather_service import apply_live_climate, weather_insight as build_weather_insight

router = APIRouter(prefix="/predictions", tags=["predictions"])


def _build_evaluation(
    payload: FarmConditionsRequest,
    ranked: list[tuple[str, float]],
    explanation: str,
    ml_info: dict,
) -> CropPredictionResponse:
    top_crop = ranked[0][0]
    district = payload.district
    health_score, health_label = soil_health_assessment(
        payload.nitrogen,
        payload.phosphorus,
        payload.potassium,
        payload.soil_ph,
        payload.soil_moisture,
    )
    fert_raw, analysis, fert_notes = recommend_fertilizers(
        crop=top_crop,
        nitrogen=payload.nitrogen,
        phosphorus=payload.phosphorus,
        potassium=payload.potassium,
        soil_ph=payload.soil_ph,
        soil_moisture=payload.soil_moisture,
        soil_type=payload.soil_type,
        season=payload.season,
        district=district,
    )
    adss_notes = list(ml_info.get("precision_notes_adss") or [])
    if ml_info.get("fertilizer_applicable", True):
        notes = adss_notes + fert_notes
    else:
        notes = adss_notes
    environment_analysis = list(ml_info.get("environment_analysis") or [])
    weather_raw = build_weather_insight(
        season=payload.season,
        district=district,
        rainfall_mm=payload.rainfall_mm,
        temperature_c=payload.temperature_c,
        humidity_pct=payload.humidity_pct,
    )
    fertilizers = (
        [FertilizerRecommendationItem(**f) for f in fert_raw]
        if ml_info.get("fertilizer_applicable", True)
        else []
    )
    confidence = round(ranked[0][1], 6)
    improvements = build_improvement_actions(
        confidence,
        top_crop,
        nitrogen=payload.nitrogen,
        phosphorus=payload.phosphorus,
        potassium=payload.potassium,
        soil_moisture=payload.soil_moisture,
        temperature_c=payload.temperature_c,
        humidity_pct=payload.humidity_pct,
        soil_ph=payload.soil_ph,
        rainfall_mm=payload.rainfall_mm,
        soil_type=payload.soil_type,
        season=payload.season or current_rwanda_season(),
        soil_health_score=health_score,
    )
    season_id = payload.season or current_rwanda_season()
    return CropPredictionResponse(
        top_crop=top_crop,
        top_confidence=confidence,
        explanation=explanation,
        full_ranking=[CropRankItem(crop=n, confidence=round(s, 6)) for n, s in ranked],
        model_version=str(ml_info.get("model_version", "unknown")),
        soil_health_score=health_score,
        soil_health_label=health_label,
        fertilizers=fertilizers,
        nutrient_analysis=NutrientAnalysis(**analysis),
        weather_insight=_parse_weather(weather_raw),
        precision_notes=notes,
        environment_analysis=environment_analysis,
        season_used=season_id,
        season_label=season_label(season_id),
        improvement_actions=improvements,
    )


@router.post("/evaluate", response_model=CropPredictionResponse)
def evaluate(
    payload: FarmConditionsRequest,
    user: UserRecord = Depends(require_approved_farmer),
):
    district = payload.district or getattr(user, "district", None)
    season = current_rwanda_season()
    temp, hum, rain, _climate_meta = apply_live_climate(
        district=district,
        temperature_c=payload.temperature_c,
        humidity_pct=payload.humidity_pct,
        rainfall_mm=payload.rainfall_mm,
        use_live=payload.use_live_climate,
    )
    payload = payload.model_copy(
        update={
            "district": district,
            "season": season,
            "temperature_c": temp,
            "humidity_pct": hum,
            "rainfall_mm": rain,
        }
    )

    try:
        ranked, explanation, ml_info = predict_ranked(
            nitrogen=payload.nitrogen,
            phosphorus=payload.phosphorus,
            potassium=payload.potassium,
            soil_moisture=payload.soil_moisture,
            temperature_c=payload.temperature_c,
            humidity_pct=payload.humidity_pct,
            soil_ph=payload.soil_ph,
            rainfall_mm=payload.rainfall_mm,
            soil_type=payload.soil_type,
            season=season,
            district=district,
        )
    except FileNotFoundError as e:
        raise HTTPException(status_code=503, detail=str(e)) from e

    result = _build_evaluation(payload, ranked, explanation, ml_info)
    prediction_id = None

    if payload.persist:
        prediction_id = create_prediction(
            user.uid,
            {
                "nitrogen": payload.nitrogen,
                "phosphorus": payload.phosphorus,
                "potassium": payload.potassium,
                "soil_moisture": payload.soil_moisture,
                "temperature_c": payload.temperature_c,
                "humidity_pct": payload.humidity_pct,
                "soil_ph": payload.soil_ph,
                "rainfall_mm": payload.rainfall_mm,
                "soil_type": payload.soil_type,
                "season": payload.season,
                "district": payload.district,
                "model_version": result.model_version,
                "top_crop": result.top_crop,
                "top_confidence": result.top_confidence,
                "explanation": result.explanation,
                "full_ranking": [{"crop": n, "confidence": s} for n, s in ranked],
                "soil_health_score": result.soil_health_score,
                "soil_health_label": result.soil_health_label,
                "fertilizers": [f.model_dump() for f in result.fertilizers],
                "nutrient_analysis": result.nutrient_analysis.model_dump() if result.nutrient_analysis else None,
                "weather_insight": result.weather_insight.model_dump() if result.weather_insight else None,
                "precision_notes": result.precision_notes,
                "environment_analysis": result.environment_analysis,
                "season_used": result.season_used,
                "improvement_actions": result.improvement_actions,
            },
        )

    return result.model_copy(update={"prediction_id": prediction_id})


@router.get("/history", response_model=list[PredictionHistoryItem])
def history(limit: int = 30, user: UserRecord = Depends(require_farmer)):
    rows = list_predictions_for_user(user.uid, limit=min(limit, 100))
    if not rows and user.is_approved and user.field_data:
        try:
            build_and_save_farmer_plan(
                user.uid,
                user.field_data,
                district=user.district,
                use_live_climate=False,
            )
            rows = list_predictions_for_user(user.uid, limit=min(limit, 100))
        except (ValueError, FileNotFoundError):
            pass
    items = []
    for r in rows:
        created = r.get("created_at")
        if created is None:
            created = datetime.now(timezone.utc)
        elif hasattr(created, "timestamp"):
            created = datetime.fromtimestamp(created.timestamp(), tz=timezone.utc)
        elif not isinstance(created, datetime):
            created = datetime.now(timezone.utc)
        items.append(
            PredictionHistoryItem(
                id=r["id"],
                top_crop=r.get("top_crop", ""),
                top_confidence=float(r.get("top_confidence", 0)),
                created_at=created,
                soil_ph=float(r.get("soil_ph", 0)),
                nitrogen=float(r.get("nitrogen", 0)),
                soil_type=str(r.get("soil_type", "loam")),
                season=str(r.get("season", "season_a")),
                soil_health_score=float(r.get("soil_health_score", 0)),
            )
        )
    return items


def _parse_weather(wi: dict | None) -> WeatherInsight | None:
    if not wi:
        return None
    daily = [ForecastDayItem(**d) for d in (wi.get("forecast_daily") or []) if isinstance(d, dict)]
    return WeatherInsight(**{**wi, "forecast_daily": daily})


def _parse_fertilizers(row: dict) -> list[FertilizerRecommendationItem]:
    out = []
    for f in row.get("fertilizers") or []:
        try:
            out.append(FertilizerRecommendationItem(**f))
        except Exception:
            continue
    return out


@router.get("/history/{prediction_id}", response_model=PredictionDetailItem)
def history_detail(prediction_id: str, user: UserRecord = Depends(require_farmer)):
    row = get_prediction(prediction_id, user.uid)
    if row is None:
        raise HTTPException(status_code=404, detail="Prediction not found")
    created = row.get("created_at")
    if created is not None and hasattr(created, "timestamp"):
        created = datetime.fromtimestamp(created.timestamp(), tz=timezone.utc)
    ranking = [
        CropRankItem(crop=x.get("crop", ""), confidence=float(x.get("confidence", 0)))
        for x in (row.get("full_ranking") or [])
    ]
    na = row.get("nutrient_analysis")
    wi = row.get("weather_insight")
    fb = get_feedback_for_prediction(prediction_id, user.uid)
    return PredictionDetailItem(
        id=row["id"],
        top_crop=row.get("top_crop", ""),
        top_confidence=float(row.get("top_confidence", 0)),
        explanation=row.get("explanation", ""),
        model_version=str(row.get("model_version", "")),
        created_at=created,
        nitrogen=float(row.get("nitrogen", 0)),
        phosphorus=float(row.get("phosphorus", 0)),
        potassium=float(row.get("potassium", 0)),
        soil_moisture=float(row.get("soil_moisture", 0)),
        temperature_c=float(row.get("temperature_c", 0)),
        humidity_pct=float(row.get("humidity_pct", 0)),
        soil_ph=float(row.get("soil_ph", 0)),
        rainfall_mm=float(row.get("rainfall_mm", 0)),
        soil_type=str(row.get("soil_type", "loam")),
        season=str(row.get("season", "season_a")),
        district=row.get("district"),
        soil_health_score=float(row.get("soil_health_score", 0)),
        soil_health_label=str(row.get("soil_health_label", "")),
        fertilizers=_parse_fertilizers(row),
        nutrient_analysis=NutrientAnalysis(**na) if na else None,
        weather_insight=_parse_weather(wi),
        precision_notes=list(row.get("precision_notes") or []),
        environment_analysis=list(row.get("environment_analysis") or []),
        full_ranking=ranking,
        has_feedback=fb is not None,
        feedback_rating=int(fb.get("yield_rating")) if fb else None,
        season_label=season_label(str(row.get("season", "season_a"))),
        improvement_actions=list(row.get("improvement_actions") or []),
    )
