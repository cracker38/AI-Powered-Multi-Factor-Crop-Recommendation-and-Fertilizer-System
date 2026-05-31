"""
Rwanda-focused crop suitability rules combined with ML probabilities.

Scores reflect soil chemistry, moisture, rainfall, temperature, season, and soil texture.
"""
from __future__ import annotations

from dataclasses import dataclass

# Rwanda growing seasons (aligned with lib/core/agriculture_options.dart)
SEASON_LABELS = {
    "season_a": "Season A (Sep-Jan, short rains)",
    "season_b": "Season B (Feb-Jun, long rains)",
    "season_c": "Season C (Jul-Aug, dry season)",
}


@dataclass(frozen=True)
class CropProfile:
    name: str
    ph_min: float
    ph_max: float
    rainfall_min: float
    rainfall_max: float
    temp_min: float
    temp_max: float
    moisture_min: float
    moisture_max: float
    n_min: float
    n_max: float
    p_min: float
    p_max: float
    k_min: float
    k_max: float
    preferred_seasons: frozenset[str]
    preferred_soils: frozenset[str]
    drought_tolerant: bool = False
    notes: str = ""


# Extension-grade profiles for common Rwanda smallholder crops
CROP_PROFILES: dict[str, CropProfile] = {
    "maize": CropProfile(
        "maize", 5.5, 7.5, 500, 1200, 18, 30, 45, 75,
        80, 180, 40, 90, 40, 90,
        frozenset({"season_a", "season_b"}),
        frozenset({"loam", "clay", "silt", "volcanic"}),
        notes="Staple cereal; plant at onset of rains with split N application.",
    ),
    "rice": CropProfile(
        "rice", 5.5, 7.0, 900, 2500, 20, 32, 70, 95,
        90, 150, 40, 80, 40, 80,
        frozenset({"season_a", "season_b"}),
        frozenset({"clay", "silt", "loam"}),
        notes="Requires bunded fields or irrigation; high water demand.",
    ),
    "beans": CropProfile(
        "beans", 5.8, 7.0, 450, 900, 18, 28, 40, 70,
        20, 80, 30, 70, 30, 70,
        frozenset({"season_a", "season_b"}),
        frozenset({"loam", "sandy", "volcanic", "silt"}),
        notes="Legume — fixes nitrogen; good rotation crop after maize.",
    ),
    "potato": CropProfile(
        "potato", 5.0, 6.5, 600, 1100, 15, 24, 50, 80,
        100, 180, 50, 100, 120, 220,
        frozenset({"season_a", "season_b"}),
        frozenset({"loam", "sandy", "volcanic", "silt"}),
        notes="Highland crop (1,800–2,500 m); sensitive to heat and waterlogging.",
    ),
    "cassava": CropProfile(
        "cassava", 5.0, 7.5, 500, 1500, 22, 35, 35, 65,
        40, 120, 20, 60, 40, 100,
        frozenset({"season_a", "season_b", "season_c"}),
        frozenset({"sandy", "loam", "volcanic"}),
        drought_tolerant=True,
        notes="Drought-tolerant root crop; low input requirement.",
    ),
    "coffee": CropProfile(
        "coffee", 5.2, 6.5, 900, 1800, 18, 26, 55, 80,
        100, 200, 30, 70, 80, 220,
        frozenset({"season_a", "season_b"}),
        frozenset({"volcanic", "loam", "silt"}),
        notes="Perennial cash crop; shade and mulching improve quality.",
    ),
    "tea": CropProfile(
        "tea", 4.5, 6.0, 1000, 2200, 16, 24, 60, 85,
        120, 200, 40, 80, 100, 200,
        frozenset({"season_a", "season_b"}),
        frozenset({"volcanic", "silt", "peat"}),
        notes="Acidic volcanic soils; year-round leaf harvest after establishment.",
    ),
    "banana": CropProfile(
        "banana", 5.5, 7.0, 800, 2000, 20, 30, 55, 85,
        150, 250, 40, 80, 200, 350,
        frozenset({"season_a", "season_b"}),
        frozenset({"loam", "volcanic", "clay"}),
        notes="High potassium demand; mulch and organic matter essential.",
    ),
    "sorghum": CropProfile(
        "sorghum", 5.5, 8.0, 400, 900, 22, 35, 30, 60,
        60, 120, 30, 60, 30, 70,
        frozenset({"season_b", "season_c"}),
        frozenset({"sandy", "loam", "clay"}),
        drought_tolerant=True,
        notes="Suitable for drier lowland areas and Season C.",
    ),
    "sweet_potato": CropProfile(
        "sweet_potato", 5.5, 6.8, 500, 1200, 20, 30, 40, 70,
        50, 110, 30, 70, 50, 120,
        frozenset({"season_a", "season_b"}),
        frozenset({"sandy", "loam", "volcanic"}),
        drought_tolerant=True,
        notes="Fast-growing root crop; avoid waterlogged clay.",
    ),
    "wheat": CropProfile(
        "wheat", 6.0, 7.5, 450, 900, 12, 22, 45, 70,
        80, 160, 40, 80, 40, 80,
        frozenset({"season_a"}),
        frozenset({"loam", "volcanic", "silt"}),
        notes="Cool highland season crop; limited to suitable altitudes.",
    ),
    "chickpea": CropProfile(
        "chickpea", 6.0, 7.5, 350, 700, 18, 28, 35, 60,
        20, 60, 25, 55, 25, 55,
        frozenset({"season_b", "season_c"}),
        frozenset({"sandy", "loam"}),
        drought_tolerant=True,
        notes="Pulse crop for drier periods; improves soil nitrogen.",
    ),
    "grapes": CropProfile(
        "grapes", 5.5, 7.0, 500, 900, 18, 28, 40, 65,
        60, 120, 40, 80, 60, 120,
        frozenset({"season_b"}),
        frozenset({"sandy", "loam", "volcanic"}),
        notes="Specialty crop; requires drainage and trellising.",
    ),
    "apple": CropProfile(
        "apple", 5.5, 7.0, 600, 1100, 12, 22, 45, 70,
        80, 150, 40, 80, 60, 140,
        frozenset({"season_a", "season_b"}),
        frozenset({"loam", "volcanic", "silt"}),
        notes="Highland fruit; long-term orchard investment.",
    ),
}


def _range_score(value: float, low: float, high: float, margin: float = 0.15) -> float:
    """1.0 inside [low, high]; decays outside with soft margin."""
    if low <= value <= high:
        return 1.0
    span = (high - low) * margin or 1.0
    if value < low:
        return max(0.0, 1.0 - (low - value) / span)
    return max(0.0, 1.0 - (value - high) / span)


def suitability_score(
    crop: str,
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
) -> tuple[float, list[str]]:
    """Return 0–1 suitability and human-readable factor notes."""
    key = crop.lower().strip().replace(" ", "_")
    profile = CROP_PROFILES.get(key)
    if profile is None:
        return 0.55, [f"{crop}: limited Rwanda profile — ML weight applied."]

    factors: list[tuple[str, float, str]] = [
        ("pH", _range_score(soil_ph, profile.ph_min, profile.ph_max), f"pH {soil_ph:.1f}"),
        ("rainfall", _range_score(rainfall_mm, profile.rainfall_min, profile.rainfall_max), f"rainfall {rainfall_mm:.0f} mm"),
        ("temperature", _range_score(temperature_c, profile.temp_min, profile.temp_max), f"temp {temperature_c:.1f} °C"),
        ("moisture", _range_score(soil_moisture, profile.moisture_min, profile.moisture_max), f"moisture {soil_moisture:.0f}%"),
        ("nitrogen", _range_score(nitrogen, profile.n_min, profile.n_max), f"N {nitrogen:.0f} kg/ha"),
        ("phosphorus", _range_score(phosphorus, profile.p_min, profile.p_max), f"P {phosphorus:.0f} kg/ha"),
        ("potassium", _range_score(potassium, profile.k_min, profile.k_max), f"K {potassium:.0f} kg/ha"),
    ]

    st = (soil_type or "loam").lower()
    soil_s = 1.0 if st in profile.preferred_soils else 0.55
    factors.append(("soil texture", soil_s, f"soil {st}"))

    seas = (season or "season_a").lower()
    season_s = 1.0 if seas in profile.preferred_seasons else 0.45
    if seas == "season_c" and profile.drought_tolerant:
        season_s = max(season_s, 0.75)
    factors.append(("season", season_s, SEASON_LABELS.get(seas, seas)))

    # Humidity proxy for disease pressure in very wet highland crops
    if humidity_pct > 88 and crop in ("potato", "grapes", "apple"):
        factors.append(("humidity risk", 0.6, f"high humidity {humidity_pct:.0f}% — disease risk"))

    weights = [1.2, 1.3, 1.0, 1.0, 0.9, 0.9, 0.9, 1.1, 1.4]
    total_w = sum(weights[: len(factors)])
    score = sum(f[1] * w for f, w in zip(factors, weights)) / total_w

    notes = [f"{profile.name}: {profile.notes}"]
    weak = [f"{label} ({detail})" for label, s, detail in factors if s < 0.65]
    if weak:
        notes.append("Constraints: " + "; ".join(weak[:4]))
    return round(min(1.0, max(0.0, score)), 4), notes


def hybrid_rank(
    ml_ranked: list[tuple[str, float]],
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
    ml_weight: float = 0.5,
    rule_weight: float = 0.5,
    top_k: int = 8,
) -> tuple[list[tuple[str, float]], dict[str, list[str]]]:
    """Blend ML probabilities with agronomic suitability scores."""
    crops_seen: set[str] = set()
    combined: list[tuple[str, float]] = []
    factor_notes: dict[str, list[str]] = {}

    for crop, ml_prob in ml_ranked:
        crops_seen.add(crop.lower())
        rule_s, notes = suitability_score(
            crop,
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
        hybrid = ml_weight * ml_prob + rule_weight * rule_s
        combined.append((crop, hybrid))
        factor_notes[crop] = notes

    # Boost rule-strong crops missing from ML top list
    for key, profile in CROP_PROFILES.items():
        if key in crops_seen:
            continue
        rule_s, notes = suitability_score(
            profile.name,
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
        if rule_s >= 0.72:
            combined.append((profile.name, rule_weight * rule_s * 0.85))
            factor_notes[profile.name] = notes

    combined.sort(key=lambda x: x[1], reverse=True)
    slice_ = combined[:top_k]
    total = sum(s for _, s in slice_) or 1.0
    top = [(c, round(s / total, 6)) for c, s in slice_]
    return top, factor_notes
