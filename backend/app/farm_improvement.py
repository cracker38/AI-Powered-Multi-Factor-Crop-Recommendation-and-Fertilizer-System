"""Action plan when crop suitability is below 50% — ordered steps for farmers."""
from __future__ import annotations

from app.crop_suitability import CROP_PROFILES, suitability_score
from app.rwanda_season import SEASON_INFO, season_label


def build_improvement_actions(
    confidence: float,
    top_crop: str,
    *,
    nitrogen: float,
    phosphorus: float,
    potassium: float,
    soil_moisture: float,
    temperature_c: float,
    humidity_pct: float,
    soil_ph: float,
    rainfall_mm: float,
    soil_type: str,
    season: str,
    soil_health_score: float,
) -> list[str]:
    """Prioritized field actions when suitability index is under 50%."""
    if confidence >= 0.5:
        return []

    actions: list[tuple[int, str]] = []

    # 1 — Soil chemistry foundation
    if soil_ph < 5.5:
        actions.append(
            (
                10,
                "Apply agricultural lime (2–4 t/ha) and retest pH in 4–6 weeks. "
                f"Current pH {soil_ph:.1f} is too acidic for most crops — fertilizer will be wasted until corrected.",
            )
        )
    elif soil_ph < 5.8:
        actions.append(
            (
                20,
                f"Lime lightly (1.5–2 t/ha) to move pH from {soil_ph:.1f} toward 6.0–6.5 before planting {top_crop}.",
            )
        )
    elif soil_ph > 7.8:
        actions.append(
            (
                15,
                f"Add compost (5–8 t/ha) and sulfur to reduce alkaline pH ({soil_ph:.1f}); unlocks phosphorus and micronutrients.",
            )
        )

    # 2 — Official soil test
    if soil_health_score < 50:
        actions.append(
            (
                25,
                "Request a full soil test (N, P, K, pH, organic matter) from RAB or district extension — "
                "update the app with lab results for a precise recommendation.",
            )
        )

    # 3 — Macro-nutrient gaps (after pH)
    if nitrogen < 40:
        actions.append(
            (
                30,
                f"Nitrogen is low ({nitrogen:.0f} kg/ha). Incorporate compost/FYM, then apply split urea after pH is suitable.",
            )
        )
    if phosphorus < 30:
        actions.append(
            (
                35,
                f"Phosphorus is low ({phosphorus:.0f} kg/ha). Apply DAP at planting in a band beside the seed row.",
            )
        )
    if potassium < 30:
        actions.append(
            (
                40,
                f"Potassium is low ({potassium:.0f} kg/ha). Apply MOP (muriate of potash) before flowering or tuber fill.",
            )
        )

    # 4 — Water / moisture
    if soil_moisture < 35:
        actions.append(
            (
                45,
                f"Soil moisture is only {soil_moisture:.0f}% — mulch heavily, use tied ridges, or irrigate before fertilizer application.",
            )
        )
    elif soil_moisture > 85:
        actions.append(
            (
                46,
                "Field is waterlogged — improve drainage (furrows, raised beds) before sowing to avoid root rot.",
            )
        )

    if rainfall_mm < 400 and season == "season_c":
        actions.append(
            (
                50,
                f"Rainfall ({rainfall_mm:.0f} mm) is low in {season_label(season)} — choose drought-tolerant crops "
                "(cassava, sorghum, sweet potato) or delay planting until rains start.",
            )
        )

    # 5 — Season × crop mismatch
    profile = CROP_PROFILES.get(top_crop.lower().replace(" ", "_"))
    if profile and season not in profile.preferred_seasons:
        alt = SEASON_INFO.get(season, {}).get("advice", "")
        actions.append(
            (
                55,
                f"{top_crop.title()} is not ideal for {season_label(season)}. {alt} "
                f"Better windows: {', '.join(season_label(s) for s in sorted(profile.preferred_seasons))}.",
            )
        )

    # 6 — Suitability weak factors for recommended crop
    _, notes = suitability_score(
        top_crop,
        nitrogen=nitrogen,
        phosphorus=phosphorus,
        potassium=potassium,
        soil_moisture=soil_moisture,
        temperature_c=temperature_c,
        humidity_pct=humidity_pct,
        soil_ph=soil_ph,
        rainfall_mm=rainfall_mm,
        soil_type=soil_type,
        season=season,
    )
    for note in notes:
        if note.startswith("Constraints:"):
            actions.append((60, note.replace("Constraints:", "Address field limits —")))

    # 7 — Soil texture
    st = (soil_type or "loam").lower()
    if st == "sandy" and potassium < 50:
        actions.append(
            (
                65,
                "Sandy soil loses nutrients quickly — add 6–10 t/ha compost and use split fertilizer applications.",
            )
        )

    if not actions:
        actions.append(
            (
                70,
                "Suitability is below 50% — verify all field readings, retest soil, and compare ranked alternatives below.",
            )
        )

    actions.sort(key=lambda x: x[0])
    numbered = [f"{i + 1}. {text}" for i, (_, text) in enumerate(actions[:6])]
    numbered.append(
        "Re-run analysis after completing the first 2–3 steps for an updated crop and fertilizer plan."
    )
    return numbered
