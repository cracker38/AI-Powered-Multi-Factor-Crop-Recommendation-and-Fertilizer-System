"""Build and persist admin-style crop + fertilizer plans for farmers."""
from __future__ import annotations

from typing import Any

from app.farm_improvement import build_improvement_actions
from app.fertilizer_service import recommend_fertilizers, soil_health_assessment
from app.firestore_db import create_prediction
from app.ml_service import predict_ranked
from app.rwanda_season import current_rwanda_season, season_label
from app.weather_service import apply_live_climate, weather_insight as build_weather_insight


def _required_field_keys() -> tuple[str, ...]:
    return (
        "nitrogen",
        "phosphorus",
        "potassium",
        "soil_moisture",
        "temperature_c",
        "humidity_pct",
        "soil_ph",
        "rainfall_mm",
        "soil_type",
    )


def normalize_field_data(field_data: dict[str, Any]) -> dict[str, Any]:
    missing = [k for k in _required_field_keys() if field_data.get(k) is None]
    if missing:
        raise ValueError(f"Missing field data: {', '.join(missing)}")
    return {k: field_data[k] for k in _required_field_keys()}


def build_and_save_farmer_plan(
    uid: str,
    field_data: dict[str, Any],
    *,
    district: str | None = None,
    use_live_climate: bool = False,
) -> str:
    """Run ML recommendation and save a prediction row. Returns the new prediction id."""
    normalized = normalize_field_data(field_data)
    temp, hum, rain, _ = apply_live_climate(
        district=district,
        temperature_c=float(normalized["temperature_c"]),
        humidity_pct=float(normalized["humidity_pct"]),
        rainfall_mm=float(normalized["rainfall_mm"]),
        use_live=use_live_climate,
    )
    normalized = {
        **normalized,
        "temperature_c": temp,
        "humidity_pct": hum,
        "rainfall_mm": rain,
    }

    season = current_rwanda_season()
    ranked, explanation, ml_info = predict_ranked(
        nitrogen=normalized["nitrogen"],
        phosphorus=normalized["phosphorus"],
        potassium=normalized["potassium"],
        soil_moisture=normalized["soil_moisture"],
        temperature_c=normalized["temperature_c"],
        humidity_pct=normalized["humidity_pct"],
        soil_ph=normalized["soil_ph"],
        rainfall_mm=normalized["rainfall_mm"],
        soil_type=normalized["soil_type"],
        season=season,
        district=district,
    )
    top_crop = ranked[0][0]
    soil_health_score, soil_health_label = soil_health_assessment(
        normalized["nitrogen"],
        normalized["phosphorus"],
        normalized["potassium"],
        normalized["soil_ph"],
        normalized["soil_moisture"],
    )
    fert_raw, nutrient_analysis, fert_notes = recommend_fertilizers(
        crop=top_crop,
        nitrogen=normalized["nitrogen"],
        phosphorus=normalized["phosphorus"],
        potassium=normalized["potassium"],
        soil_ph=normalized["soil_ph"],
        soil_moisture=normalized["soil_moisture"],
        soil_type=normalized["soil_type"],
        season=season,
        district=district,
    )
    precision_notes = list(ml_info.get("precision_notes_adss") or [])
    if ml_info.get("fertilizer_applicable", True):
        precision_notes.extend(fert_notes)
    weather_insight = build_weather_insight(
        season=season,
        district=district,
        rainfall_mm=normalized["rainfall_mm"],
        temperature_c=normalized["temperature_c"],
        humidity_pct=normalized["humidity_pct"],
    )
    improvement_actions = build_improvement_actions(
        ranked[0][1],
        top_crop,
        nitrogen=normalized["nitrogen"],
        phosphorus=normalized["phosphorus"],
        potassium=normalized["potassium"],
        soil_moisture=normalized["soil_moisture"],
        temperature_c=normalized["temperature_c"],
        humidity_pct=normalized["humidity_pct"],
        soil_ph=normalized["soil_ph"],
        rainfall_mm=normalized["rainfall_mm"],
        soil_type=normalized["soil_type"],
        season=season,
        soil_health_score=soil_health_score,
    )

    return create_prediction(
        uid,
        {
            "nitrogen": normalized["nitrogen"],
            "phosphorus": normalized["phosphorus"],
            "potassium": normalized["potassium"],
            "soil_moisture": normalized["soil_moisture"],
            "temperature_c": normalized["temperature_c"],
            "humidity_pct": normalized["humidity_pct"],
            "soil_ph": normalized["soil_ph"],
            "rainfall_mm": normalized["rainfall_mm"],
            "soil_type": normalized["soil_type"],
            "season": season,
            "district": district,
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
