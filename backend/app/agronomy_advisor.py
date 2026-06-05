"""
AI Agricultural Decision Support System (ADSS) — Rwanda crop & fertilizer logic.

Core function for each field evaluation:
  1. Analyze soil, climate, and environmental conditions
  2. Recommend suitable crops with suitability index (0–100%)
  3. Provide fertilizer recommendations when agronomically appropriate
  4. Explain reasoning clearly and scientifically
"""
from __future__ import annotations

from dataclasses import dataclass

from app.crop_suitability import SEASON_LABELS, suitability_score


@dataclass
class FieldConditions:
    nitrogen: float
    phosphorus: float
    potassium: float
    soil_moisture: float
    temperature_c: float
    humidity_pct: float
    soil_ph: float
    rainfall_mm: float
    soil_type: str
    season: str
    district: str | None = None


@dataclass
class AgronomyReport:
    """Structured ADSS output for API and UI."""
    environment_analysis: list[str]
    explanation: str
    precision_notes: list[str]
    fertilizer_applicable: bool


def analyze_environment(field: FieldConditions) -> list[str]:
    """Step 1 — scientific summary of soil, climate, and environmental context."""
    st = (field.soil_type or "loam").lower()
    season = SEASON_LABELS.get(field.season, field.season.replace("_", " "))
    lines: list[str] = []

    lines.append(
        f"Soil: {st.title()} texture · pH {field.soil_ph:.1f} · moisture {field.soil_moisture:.0f}% · "
        f"N {field.nitrogen:.0f} · P {field.phosphorus:.0f} · K {field.potassium:.0f} kg/ha."
    )

    # pH
    if field.soil_ph < 5.5:
        lines.append(
            "pH is strongly acidic — aluminium toxicity and poor phosphorus availability are likely; "
            "lime before fertilizer investment."
        )
    elif field.soil_ph < 5.8:
        lines.append("pH is moderately acidic — agricultural lime will improve nutrient uptake and root growth.")
    elif field.soil_ph <= 7.5:
        lines.append("pH is within the favourable range (≈6.0–7.5) for most annual and staple crops.")
    elif field.soil_ph <= 8.0:
        lines.append("pH is slightly alkaline — monitor iron/zinc availability; sulfur or compost may help.")
    else:
        lines.append("pH is alkaline — micronutrient lock-up is possible; adjust before high-value crops.")

    # Macronutrients
    if field.nitrogen < 40:
        lines.append("Nitrogen is low — expect slow vegetative growth unless supplemented or rotated with legumes.")
    elif field.nitrogen > 180:
        lines.append("Nitrogen is high — risk of lodging, pest pressure, and nitrate leaching on sandy soils.")
    if field.phosphorus < 30:
        lines.append("Phosphorus is low — root development and flowering may be limited; DAP at planting is typical.")
    if field.potassium < 30:
        lines.append("Potassium is low — drought stress and poor tuber/fruit quality are more likely.")
    if field.potassium > 200:
        lines.append("Potassium is abundant — suitable for banana and potato; avoid excess K on legumes.")

    # Moisture & rainfall
    if field.soil_moisture < 35:
        lines.append("Soil moisture is low — mulching, tied ridges, or irrigation recommended before sowing.")
    elif field.soil_moisture > 85:
        lines.append("Soil moisture is high — improve drainage to reduce root rot and denitrification.")
    if field.rainfall_mm < 450:
        lines.append(f"Reported rainfall ({field.rainfall_mm:.0f} mm) is low — favour drought-tolerant crops or irrigate.")
    elif field.rainfall_mm > 1400:
        lines.append(f"High rainfall ({field.rainfall_mm:.0f} mm) — ensure drainage; disease risk rises with humidity.")

    # Climate
    if field.temperature_c < 16:
        lines.append(f"Temperature ({field.temperature_c:.1f} °C) suits cool highland crops (potato, wheat, tea).")
    elif field.temperature_c > 30:
        lines.append(f"Temperature ({field.temperature_c:.1f} °C) favours heat-tolerant crops (cassava, sorghum, banana).")
    if field.humidity_pct > 85:
        lines.append(f"Humidity ({field.humidity_pct:.0f}%) increases foliar disease risk — scout potato, tomato, and fruit crops.")

    lines.append(f"Season context: {season}.")
    if field.district:
        lines.append(f"Location: {field.district} — local rainfall patterns should be cross-checked with seasonal forecasts.")

    return lines


def should_recommend_fertilizer(suitability_pct: float, soil_ph: float) -> bool:
    """Fertilizer plans when crop choice is viable and soil can respond to amendments."""
    if suitability_pct < 35:
        return False
    if soil_ph < 5.4:
        return False
    return True


def build_crop_reasoning(
    field: FieldConditions,
    top_crop: str,
    ranked: list[tuple[str, float]],
    factor_notes: dict[str, list[str]],
) -> str:
    """Step 2 & 4 — crop suitability (0–100%) and scientific explanation."""
    conf_pct = ranked[0][1] * 100
    season_label = SEASON_LABELS.get(field.season, field.season.replace("_", " "))
    parts = [
        f"Recommended crop: {top_crop.title()} — {conf_pct:.1f}% suitability index "
        f"({field.soil_type} soil, {season_label}"
        + (f", {field.district})" if field.district else ")")
        + ").",
        "The index blends ML patterns (N, P, K, pH, moisture, rainfall, temperature, humidity, "
        "soil type, season) with Rwanda extension crop profiles — scores reflect true field fit, not relative ranking.",
    ]

    top_notes = factor_notes.get(top_crop, [])
    for note in top_notes[:2]:
        parts.append(note)

    rule_s, _ = suitability_score(
        top_crop,
        nitrogen=field.nitrogen,
        phosphorus=field.phosphorus,
        potassium=field.potassium,
        soil_moisture=field.soil_moisture,
        temperature_c=field.temperature_c,
        humidity_pct=field.humidity_pct,
        soil_ph=field.soil_ph,
        rainfall_mm=field.rainfall_mm,
        soil_type=field.soil_type,
        season=field.season,
    )
    parts.append(f"Agronomic rule score for {top_crop.title()}: {rule_s * 100:.0f}% alignment with ideal ranges.")

    if conf_pct < 50:
        parts.append(
            "Suitability is below 50% — treat this as a conditional recommendation; "
            "complete soil correction steps before relying on yield forecasts."
        )
    elif conf_pct >= 75:
        parts.append("Strong match — field conditions align well with this crop's preferred environment.")

    alts = [f"{c.title()} ({s * 100:.0f}%)" for c, s in ranked[1:4] if c != top_crop]
    if alts:
        parts.append(f"Alternative crops: {', '.join(alts)}.")

    return " ".join(parts)


def build_agronomy_report(
    field: FieldConditions,
    ranked: list[tuple[str, float]],
    factor_notes: dict[str, list[str]],
    fertilizer_notes: list[str] | None = None,
) -> AgronomyReport:
    """Full ADSS report for one evaluation."""
    top_crop = ranked[0][0]
    suitability_pct = ranked[0][1] * 100
    env = analyze_environment(field)
    explanation = build_crop_reasoning(field, top_crop, ranked, factor_notes)

    precision: list[str] = [
        "AI Agricultural Decision Support — analysis based on soil test, climate inputs, and Rwanda agronomy rules.",
        *env,
    ]

    fert_ok = should_recommend_fertilizer(suitability_pct, field.soil_ph)
    if fert_ok:
        precision.append(
            f"Fertilizer plan below targets {top_crop.title()} nutrient demand after soil correction (pH priority first)."
        )
        if fertilizer_notes:
            precision.extend(fertilizer_notes)
    else:
        precision.append(
            "Fertilizer recommendations deferred — improve pH, moisture, or season–crop match before investing in inputs."
        )

    return AgronomyReport(
        environment_analysis=env,
        explanation=explanation,
        precision_notes=precision,
        fertilizer_applicable=fert_ok,
    )
