"""
Generate agronomically consistent training data from Rwanda crop profiles.

Labels are derived from the highest rule-based suitability score so ML learns
the same logic extension officers use (soil, climate, season, texture).
"""
from __future__ import annotations

import random
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT.parent / "backend"))

from app.crop_suitability import CROP_PROFILES, suitability_score  # noqa: E402

OUT = ROOT / "data" / "sample_crop_data.csv"
SOIL_TYPES = ["clay", "loam", "sandy", "silt", "volcanic", "peat"]
SEASONS = ["season_a", "season_b", "season_c"]
RNG = random.Random(42)


def _mid(lo: float, hi: float) -> float:
    return (lo + hi) / 2


def _sample_range(lo: float, hi: float, spread: float = 0.18) -> float:
    span = hi - lo
    margin = span * spread
    return round(RNG.uniform(lo - margin, hi + margin), 2)


def _profile_row(crop_key: str, profile, *, tight: bool = True) -> dict:
    spread = 0.08 if tight else 0.22
    soil = RNG.choice(list(profile.preferred_soils))
    season = RNG.choice(list(profile.preferred_seasons))
    return {
        "N": _sample_range(profile.n_min, profile.n_max, spread),
        "P": _sample_range(profile.p_min, profile.p_max, spread),
        "K": _sample_range(profile.k_min, profile.k_max, spread),
        "soil_moisture": _sample_range(profile.moisture_min, profile.moisture_max, spread),
        "temperature": _sample_range(profile.temp_min, profile.temp_max, spread),
        "humidity": round(RNG.uniform(55, 85), 1),
        "ph": _sample_range(profile.ph_min, profile.ph_max, spread),
        "rainfall": _sample_range(profile.rainfall_min, profile.rainfall_max, spread),
        "soil_type": soil,
        "season": season,
        "label": profile.name,
    }


def _best_crop_label(row: dict) -> str:
    best_crop, best_score = "", -1.0
    for key, profile in CROP_PROFILES.items():
        score, _ = suitability_score(
            profile.name,
            nitrogen=row["N"],
            phosphorus=row["P"],
            potassium=row["K"],
            soil_moisture=row["soil_moisture"],
            temperature_c=row["temperature"],
            humidity_pct=row["humidity"],
            soil_ph=row["ph"],
            rainfall_mm=row["rainfall"],
            soil_type=row["soil_type"],
            season=row["season"],
        )
        if score > best_score:
            best_score, best_crop = score, profile.name
    return best_crop or "maize"


def generate(samples_per_crop: int = 28, random_fields: int = 120) -> pd.DataFrame:
    rows: list[dict] = []

    for key, profile in CROP_PROFILES.items():
        for i in range(samples_per_crop):
            rows.append(_profile_row(key, profile, tight=i % 3 != 0))
        # Boundary stress samples (still labeled by best agronomic match)
        for _ in range(6):
            row = _profile_row(key, profile, tight=False)
            rows.append(row)

    for _ in range(random_fields):
        crop_key = RNG.choice(list(CROP_PROFILES.keys()))
        profile = CROP_PROFILES[crop_key]
        row = _profile_row(crop_key, profile, tight=False)
        row["soil_type"] = RNG.choice(SOIL_TYPES)
        row["season"] = RNG.choice(SEASONS)
        row["label"] = _best_crop_label(row)
        rows.append(row)

    df = pd.DataFrame(rows)
    df = df.drop_duplicates()
    return df


def main() -> None:
    df = generate()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(OUT, index=False)
    print(f"Wrote {len(df)} rows ({df['label'].nunique()} crops) -> {OUT}")


if __name__ == "__main__":
    main()
