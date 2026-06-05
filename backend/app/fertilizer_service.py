"""Professional fertilizer recommendations from soil test, crop demand, season, and soil type."""
from __future__ import annotations

# Crop nutrient demand (kg/ha elemental N, P, K) — Rwanda RAB / FAO smallholder guidance (simplified)
CROP_NPK_TARGETS: dict[str, dict[str, float]] = {
    "maize": {"N": 150, "P": 70, "K": 70},
    "rice": {"N": 120, "P": 60, "K": 60},
    "beans": {"N": 25, "P": 60, "K": 55},  # low N — legume
    "potato": {"N": 140, "P": 80, "K": 200},
    "sweet_potato": {"N": 80, "P": 45, "K": 120},
    "cassava": {"N": 80, "P": 35, "K": 90},
    "coffee": {"N": 180, "P": 35, "K": 200},
    "tea": {"N": 160, "P": 40, "K": 150},
    "banana": {"N": 200, "P": 40, "K": 300},
    "wheat": {"N": 130, "P": 65, "K": 65},
    "sorghum": {"N": 90, "P": 45, "K": 45},
    "chickpea": {"N": 20, "P": 50, "K": 45},
    "grapes": {"N": 100, "P": 50, "K": 120},
    "apple": {"N": 120, "P": 55, "K": 140},
}

DEFAULT_TARGET = {"N": 120, "P": 60, "K": 60}

SOIL_TYPE_MODIFIER: dict[str, float] = {
    "clay": 1.12,
    "loam": 1.0,
    "sandy": 0.82,
    "silt": 1.05,
    "volcanic": 0.95,
    "peat": 0.88,
}

SEASON_MODIFIER: dict[str, dict[str, float]] = {
    "season_a": {"N": 1.0, "P": 1.0, "K": 1.0},
    "season_b": {"N": 1.05, "P": 1.0, "K": 1.0},
    "season_c": {"N": 0.85, "P": 0.95, "K": 0.9},
}

SEASON_FERTILIZER_GUIDANCE: dict[str, str] = {
    "season_a": "Season A (short rains): apply basal P/K at planting; split N at emergence and 4 weeks.",
    "season_b": "Season B (long rains): highest yield window — complete basal and two N top-dresses.",
    "season_c": "Season C (dry): reduce N rates; prioritize organic matter and irrigation for sensitive crops.",
}


def _targets(crop: str, season: str, soil_type: str) -> dict[str, float]:
    key = crop.lower().strip().replace(" ", "_")
    base = CROP_NPK_TARGETS.get(key, DEFAULT_TARGET).copy()
    sm = SOIL_TYPE_MODIFIER.get((soil_type or "loam").lower(), 1.0)
    seas = SEASON_MODIFIER.get((season or "season_a").lower(), SEASON_MODIFIER["season_a"])
    return {k: round(base[k] * sm * seas.get(k, 1.0), 1) for k in ("N", "P", "K")}


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


def _crop_is_legume(crop: str) -> bool:
    return crop.lower() in {"beans", "chickpea", "soybean", "pea"}


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
    crop_key = crop.lower().strip().replace(" ", "_")
    targets = _targets(crop, season, soil_type)
    gaps = {
        "N": max(0.0, round(targets["N"] - nitrogen, 1)),
        "P": max(0.0, round(targets["P"] - phosphorus, 1)),
        "K": max(0.0, round(targets["K"] - potassium, 1)),
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

    region = district or "your district"
    season_key = (season or "season_a").lower()
    notes.append(SEASON_FERTILIZER_GUIDANCE.get(season_key, SEASON_FERTILIZER_GUIDANCE["season_a"]))
    notes.append(
        f"Plan for {crop.replace('_', ' ').title()} on {(soil_type or 'loam').title()} soil — "
        f"targets: N {targets['N']}, P {targets['P']}, K {targets['K']} kg/ha."
    )

    defer_macros = soil_ph < 5.5

    # pH correction (priority before macro-nutrients)
    if soil_ph < 5.8:
        ph_gap = max(0.0, 6.2 - soil_ph)
        lime_t = round(1.2 + ph_gap * 2.8, 1)
        lime_t = min(4.5, max(1.0, lime_t))
        recs.append(
            {
                "name": "Agricultural lime (CaCO₃)",
                "type": "soil_amendment",
                "application_rate": f"{lime_t:.1f}–{lime_t + 1.0:.1f} t/ha",
                "timing": "Incorporate 4–6 weeks before planting; retest pH after 3 months",
                "purpose": f"Raise pH from {soil_ph:.1f} toward 6.0–6.5 for {crop}",
                "priority": "high",
                "npk": "—",
            }
        )
        notes.append(
            "Acidic soil limits P and Ca uptake — complete liming before urea/DAP/MOP investment."
            if defer_macros
            else "Acidic soil limits nutrient uptake — lime before or with basal fertilizer."
        )
    elif soil_ph > 7.8:
        recs.append(
            {
                "name": "Elemental sulfur + compost",
                "type": "soil_amendment",
                "application_rate": "200–400 kg/ha S + 5 t/ha compost",
                "timing": "Pre-season incorporation",
                "purpose": "Lower alkaline pH and improve micronutrient availability",
                "priority": "medium",
                "npk": "—",
            }
        )

    # Legumes — minimal N
    if _crop_is_legume(crop_key):
        if gaps["N"] > 10:
            notes.append("Legume crop — avoid heavy urea; rely on rhizobia fixation after inoculation.")
        gaps["N"] = min(gaps["N"], 15)

    if defer_macros:
        notes.append("Macro fertilizers deferred until pH reaches ≥5.5 — apply lime first, then retest soil.")
        if not recs:
            recs.append(
                {
                    "name": "Soil retest after liming",
                    "type": "maintenance",
                    "application_rate": "N, P, K + pH analysis",
                    "timing": "6–8 weeks after lime incorporation",
                    "purpose": "Confirm pH correction before fertilizer application",
                    "priority": "high",
                    "npk": "—",
                }
            )
        priority_order = {"high": 0, "medium": 1, "low": 2}
        recs.sort(key=lambda r: priority_order.get(r.get("priority", "medium"), 1))
        return recs, analysis, notes

    macro_gaps = sum(1 for k in ("N", "P", "K") if gaps[k] > 12)
    use_compound_only = macro_gaps >= 3 and gaps["N"] > 15 and gaps["P"] > 10 and gaps["K"] > 10

    # Nitrogen — urea with split schedule
    if not use_compound_only and gaps["N"] > 20:
        urea_kg = round(gaps["N"] / 0.46)
        recs.append(
            {
                "name": "Urea (46% N)",
                "type": "nitrogen",
                "application_rate": f"{urea_kg} kg/ha total ({gaps['N']:.0f} kg N/ha)",
                "timing": _n_timing(crop_key, season_key),
                "purpose": f"Correct nitrogen deficit for {crop} vegetative growth and yield",
                "priority": "high" if gaps["N"] > 45 else "medium",
                "npk": "46-0-0",
            }
        )
    elif nitrogen > targets["N"] * 1.35 and not _crop_is_legume(crop_key):
        notes.append("Excess nitrogen detected — reduce urea to prevent lodging, pest pressure, and leaching.")

    # Phosphorus — DAP basal
    if not use_compound_only and gaps["P"] > 12:
        dap_kg = round(gaps["P"] / 0.20)
        recs.append(
            {
                "name": "DAP (18-46-0)",
                "type": "phosphorus",
                "application_rate": f"{dap_kg} kg/ha ({gaps['P']:.0f} kg P/ha equivalent)",
                "timing": "Basal band placement at planting — 5 cm beside seed, 5 cm deep",
                "purpose": "Root establishment and early vigour",
                "priority": "high" if gaps["P"] > 28 else "medium",
                "npk": "18-46-0",
            }
        )

    # Potassium — MOP (critical for banana, potato, coffee)
    if not use_compound_only and gaps["K"] > 12:
        mop_kg = round(gaps["K"] / 0.50)
        recs.append(
            {
                "name": "Muriate of potash (MOP, 60% K₂O)",
                "type": "potassium",
                "application_rate": f"{mop_kg} kg/ha ({gaps['K']:.0f} kg K/ha equivalent)",
                "timing": _k_timing(crop_key, season_key),
                "purpose": "Drought tolerance, tuber/fruit quality, and stem strength",
                "priority": "high" if gaps["K"] > 35 or crop_key in {"banana", "potato", "coffee"} else "medium",
                "npk": "0-0-60",
            }
        )

    # Balanced compound when all macros are moderately deficient (avoids triple overlap)
    if use_compound_only:
        n_equiv = gaps["N"]
        compound_kg = round(max(200, min(350, (n_equiv / 0.17) * 0.65)))
        recs.append(
            {
                "name": "NPK 17-17-17 compound",
                "type": "compound",
                "application_rate": f"{compound_kg} kg/ha ({round(compound_kg * 0.17):.0f} kg N, "
                f"{round(compound_kg * 0.17):.0f} kg P, {round(compound_kg * 0.17):.0f} kg K equivalent)",
                "timing": "60% basal at planting, 40% top-dress at vegetative peak",
                "purpose": "Single balanced application where N, P, and K are all below target",
                "priority": "high",
                "npk": "17-17-17",
            }
        )
        notes.append("Broad macro deficiency — compound fertilizer used instead of separate urea/DAP/MOP to avoid over-application.")

    # Micronutrients for high-value crops
    if crop_key in {"coffee", "tea", "banana"} and soil_ph > 6.5:
        recs.append(
            {
                "name": "Boron + zinc foliar spray",
                "type": "micronutrient",
                "application_rate": "1–2 g/L boron + 2 g/L zinc; 500 L/ha",
                "timing": "At flowering / vegetative flush",
                "purpose": "Prevent micronutrient deficiency in volcanic and high-pH soils",
                "priority": "low",
                "npk": "—",
            }
        )

    # Organic matter
    st = (soil_type or "").lower()
    if st in {"sandy", "peat"} or soil_moisture < 42:
        recs.append(
            {
                "name": "Compost / farmyard manure (FYM)",
                "type": "organic",
                "application_rate": "6–10 t/ha well-decomposed",
                "timing": "Incorporate 3–4 weeks before planting",
                "purpose": "Improve CEC, water retention, and microbial activity",
                "priority": "medium",
                "npk": "~1-0.5-1 (variable)",
            }
        )
        notes.append("Sandy or low-moisture field — organic matter reduces nutrient leaching.")

    if not recs:
        recs.append(
            {
                "name": "Maintenance NPK 15-15-15",
                "type": "maintenance",
                "application_rate": "120 kg/ha",
                "timing": "Mid-season top-dress only",
                "purpose": f"Soil nutrients near optimal for {crop}; maintain fertility",
                "priority": "low",
                "npk": "15-15-15",
            }
        )

    notes.append("Apply fertilizer when soil is moist; avoid application before heavy rain (>20 mm forecast).")
    notes.append(f"Field-specific plan for {region} — confirm rates with local RAB extension officer.")
    notes.append("Store fertilizers dry; calibrate spreader or use measured banding for accuracy.")

    # Sort by priority
    priority_order = {"high": 0, "medium": 1, "low": 2}
    recs.sort(key=lambda r: priority_order.get(r.get("priority", "medium"), 1))
    return recs, analysis, notes


def _n_timing(crop: str, season: str) -> str:
    if crop == "maize":
        return "1/3 at planting, 1/3 at knee-high, 1/3 before tasselling"
    if crop == "rice":
        return "1/2 at transplanting, 1/2 at tillering"
    if crop in {"potato", "sweet_potato"}:
        return "1/2 at planting, 1/2 at tuber initiation"
    if crop == "coffee":
        return "Split after main rains: March and September dressings"
    return "Split: 50% basal, 50% mid-vegetative stage"


def _k_timing(crop: str, season: str) -> str:
    if crop == "banana":
        return "Quarter monthly around mat; mulch with crop residues"
    if crop == "potato":
        return "60% at planting, 40% at tuber bulking"
    return "50% basal with P, 50% before flowering or tuber fill"
