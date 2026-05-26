"""Rule-based fertilizer recommendations from soil nutrients, crop, season, and soil type."""
from __future__ import annotations

# Target N-P-K (kg/ha nutrient uptake guidance) by crop — simplified for Rwanda smallholders
CROP_NPK_TARGETS: dict[str, dict[str, float]] = {
    "rice": {"N": 120, "P": 60, "K": 60},
    "maize": {"N": 150, "P": 70, "K": 70},
    "beans": {"N": 80, "P": 50, "K": 50},
    "potato": {"N": 140, "P": 80, "K": 120},
    "cassava": {"N": 100, "P": 40, "K": 80},
    "coffee": {"N": 180, "P": 35, "K": 200},
    "tea": {"N": 160, "P": 40, "K": 150},
    "banana": {"N": 200, "P": 40, "K": 300},
    "wheat": {"N": 130, "P": 65, "K": 65},
    "sorghum": {"N": 90, "P": 45, "K": 45},
}

DEFAULT_TARGET = {"N": 120, "P": 60, "K": 60}

SOIL_TYPE_MODIFIER: dict[str, float] = {
    "clay": 1.1,
    "loam": 1.0,
    "sandy": 0.85,
    "silt": 1.05,
    "volcanic": 1.0,
    "peat": 0.9,
}

SEASON_MODIFIER: dict[str, dict[str, float]] = {
    "season_a": {"N": 1.0, "P": 1.0, "K": 1.0},  # Sep–Jan
    "season_b": {"N": 0.95, "P": 1.05, "K": 1.0},  # Feb–Jun
    "season_c": {"N": 0.9, "P": 1.0, "K": 0.95},  # Jul–Aug
}


def _targets(crop: str, season: str, soil_type: str) -> dict[str, float]:
    base = CROP_NPK_TARGETS.get(crop.lower().strip(), DEFAULT_TARGET).copy()
    sm = SOIL_TYPE_MODIFIER.get((soil_type or "loam").lower(), 1.0)
    seas = SEASON_MODIFIER.get((season or "season_a").lower(), SEASON_MODIFIER["season_a"])
    return {k: base[k] * sm * seas.get(k, 1.0) for k in ("N", "P", "K")}


def soil_health_assessment(n: float, p: float, k: float, ph: float, moisture: float) -> tuple[float, str]:
    score = 100.0
    if ph < 5.5 or ph > 8.0:
        score -= 25
    elif ph < 6.0 or ph > 7.5:
        score -= 10
    if n < 40:
        score -= 20
    elif n < 70:
        score -= 8
    if p < 30:
        score -= 15
    elif p < 50:
        score -= 5
    if k < 30:
        score -= 15
    elif k < 50:
        score -= 5
    if moisture < 25 or moisture > 85:
        score -= 10
    score = max(0, min(100, score))
    if score >= 75:
        label = "Good"
    elif score >= 50:
        label = "Moderate"
    else:
        label = "Needs improvement"
    return round(score, 1), label


def recommend_fertilizers(
    *,
    crop: str,
    nitrogen: float,
    phosphorus: float,
    potassium: float,
    soil_ph: float,
    soil_moisture: float,
    soil_type: str,
    season: str,
    district: str | None,
) -> tuple[list[dict], dict, list[str]]:
    """Returns (fertilizer list, nutrient_analysis dict, precision notes)."""
    targets = _targets(crop, season, soil_type)
    gaps = {
        "N": max(0, targets["N"] - nitrogen),
        "P": max(0, targets["P"] - phosphorus),
        "K": max(0, targets["K"] - potassium),
    }
    analysis = {
        "current": {"N": nitrogen, "P": phosphorus, "K": potassium},
        "optimal": targets,
        "gaps_kg_per_ha": gaps,
        "soil_ph": soil_ph,
        "soil_type": soil_type or "loam",
        "season": season or "season_a",
        "district": district,
    }
    recs: list[dict] = []
    notes: list[str] = []

    # pH correction
    if soil_ph < 5.8:
        recs.append(
            {
                "name": "Agricultural lime (CaCO₃)",
                "type": "soil_amendment",
                "application_rate": "2–4 t/ha before planting",
                "timing": "4–6 weeks before sowing",
                "purpose": f"Raise pH from {soil_ph:.1f} toward 6.0–6.5 for {crop}",
                "priority": "high",
                "npk": "—",
            }
        )
        notes.append("Acidic soil detected — liming improves nutrient availability and reduces aluminum toxicity.")
    elif soil_ph > 7.8:
        recs.append(
            {
                "name": "Elemental sulfur or organic matter",
                "type": "soil_amendment",
                "application_rate": "200–500 kg/ha sulfur equivalent",
                "timing": "Pre-season incorporation",
                "purpose": "Gradually lower alkaline pH for better micronutrient uptake",
                "priority": "medium",
                "npk": "—",
            }
        )

    # Nitrogen
    if gaps["N"] > 25:
        urea_kg = round(gaps["N"] / 0.46, 0)  # 46% N in urea
        recs.append(
            {
                "name": "Urea (46% N)",
                "type": "nitrogen",
                "application_rate": f"{urea_kg}–{urea_kg + 30} kg/ha split doses",
                "timing": _split_timing(season, "N"),
                "purpose": f"Close nitrogen gap (~{gaps['N']:.0f} kg N/ha) for {crop}",
                "priority": "high" if gaps["N"] > 50 else "medium",
                "npk": "46-0-0",
            }
        )
    elif nitrogen > targets["N"] * 1.3:
        notes.append("Nitrogen levels are high — reduce urea to avoid lodging and environmental loss.")

    # Phosphorus
    if gaps["P"] > 15:
        dap_kg = round(gaps["P"] / 0.20, 0)  # DAP ~20% P
        recs.append(
            {
                "name": "DAP (18-46-0)",
                "type": "phosphorus",
                "application_rate": f"{dap_kg}–{dap_kg + 25} kg/ha at planting",
                "timing": "Basal application at planting",
                "purpose": f"Supply phosphorus for root development ({crop})",
                "priority": "high" if gaps["P"] > 30 else "medium",
                "npk": "18-46-0",
            }
        )

    # Potassium
    if gaps["K"] > 15:
        mop_kg = round(gaps["K"] / 0.50, 0)  # MOP ~50% K2O
        recs.append(
            {
                "name": "Muriate of potash (MOP)",
                "type": "potassium",
                "application_rate": f"{mop_kg}–{mop_kg + 20} kg/ha",
                "timing": _split_timing(season, "K"),
                "purpose": f"Improve drought tolerance and yield quality for {crop}",
                "priority": "high" if gaps["K"] > 40 else "medium",
                "npk": "0-0-60",
            }
        )

    # Balanced NPK if multiple gaps
    if gaps["N"] > 15 and gaps["P"] > 10 and gaps["K"] > 10:
        recs.append(
            {
                "name": "NPK 17-17-17 (compound fertilizer)",
                "type": "compound",
                "application_rate": "200–300 kg/ha",
                "timing": "Split: 50% at planting, 50% top-dress",
                "purpose": "Balanced macro-nutrients for steady crop growth",
                "priority": "medium",
                "npk": "17-17-17",
            }
        )

    # Organic matter for sandy/low moisture
    st = (soil_type or "").lower()
    if st == "sandy" or soil_moisture < 40:
        recs.append(
            {
                "name": "Compost / FYM (farmyard manure)",
                "type": "organic",
                "application_rate": "5–10 t/ha",
                "timing": "Incorporate 2–4 weeks before planting",
                "purpose": "Improve water retention and soil biology",
                "priority": "medium",
                "npk": "Variable",
            }
        )
        notes.append("Low moisture or sandy soil — organic matter reduces fertilizer runoff.")

    if not recs:
        recs.append(
            {
                "name": "Maintenance dose — NPK 15-15-15",
                "type": "maintenance",
                "application_rate": "100–150 kg/ha",
                "timing": "Mid-season top-dress",
                "purpose": f"Soil nutrients are near optimal for {crop}; maintain fertility",
                "priority": "low",
                "npk": "15-15-15",
            }
        )

    notes.append(
        "Apply fertilizers based on soil test; split doses reduce waste and environmental impact."
    )
    notes.append(f"Precision plan tailored for {crop} in {(district or 'your region')} during {season.replace('_', ' ').title()}.")
    return recs, analysis, notes


def _split_timing(season: str, nutrient: str) -> str:
    s = (season or "season_a").lower()
    if nutrient == "N":
        return "Season A: 1/3 at planting, 2/3 at tillering/vegetative growth"
    if nutrient == "K":
        return "50% basal, 50% before flowering"
    return "At planting and mid-season"
