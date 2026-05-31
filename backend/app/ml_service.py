from __future__ import annotations

import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

from app.crop_suitability import SEASON_LABELS, hybrid_rank, suitability_score

MODEL_DIR = Path(__file__).resolve().parent.parent / "models"
MODEL_PATH = MODEL_DIR / "crop_model.joblib"
META_PATH = MODEL_DIR / "model_meta.json"
ACTIVE_DATASET = MODEL_DIR / "active_dataset.csv"
DEFAULT_DATASET = Path(__file__).resolve().parent.parent.parent / "ml" / "data" / "sample_crop_data.csv"

FEATURE_ORDER = ["N", "P", "K", "soil_moisture", "temperature", "humidity", "ph", "rainfall"]


def _load_meta() -> dict:
    if META_PATH.exists():
        return json.loads(META_PATH.read_text(encoding="utf-8"))
    return {}


def load_pipeline():
    if not MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Trained model not found at {MODEL_PATH}. Run: python ml/train.py"
        )
    return joblib.load(MODEL_PATH)


def build_explanation(
    row: dict,
    top: str,
    ranked: list[tuple[str, float]],
    *,
    soil_type: str,
    season: str,
    district: str | None,
    factor_notes: dict[str, list[str]],
) -> str:
    conf_pct = ranked[0][1] * 100
    season_label = SEASON_LABELS.get(season, season.replace("_", " "))
    parts = [
        f"Primary recommendation: {top.title()} ({conf_pct:.1f}% suitability index) "
        f"for {soil_type} soil during {season_label}"
        + (f" in {district}." if district else "."),
        "This ranking blends machine-learning patterns from historical crop–soil data "
        "with Rwanda extension guidelines for nutrients, pH, rainfall, and season timing.",
    ]

    top_notes = factor_notes.get(top, [])
    if top_notes:
        parts.append(top_notes[0])
    if len(top_notes) > 1:
        parts.append(top_notes[1])

    ph = row["ph"]
    if ph < 5.8:
        parts.append(
            f"Soil pH ({ph:.1f}) is acidic — liming before planting improves P availability and root growth."
        )
    elif ph > 7.5:
        parts.append(f"Soil pH ({ph:.1f}) is alkaline — consider sulfur or organic matter to unlock micronutrients.")

    if row["N"] < 50:
        parts.append("Nitrogen is below typical smallholder levels; plan split urea or legume rotation.")
    if row["rainfall"] < 450 and season == "season_c":
        parts.append("Dry-season conditions favour drought-tolerant crops (cassava, sorghum, sweet potato).")

    alts = [c for c, _ in ranked[1:3] if c != top]
    if alts:
        parts.append(f"Strong alternatives: {', '.join(a.title() for a in alts)}.")

    return " ".join(parts)


def predict_ranked(
    *,
    nitrogen: float,
    phosphorus: float,
    potassium: float,
    soil_moisture: float,
    temperature_c: float,
    humidity_pct: float,
    soil_ph: float,
    rainfall_mm: float,
    soil_type: str = "loam",
    season: str = "season_a",
    district: str | None = None,
    top_k: int = 8,
) -> tuple[list[tuple[str, float]], str, dict]:
    pipeline = load_pipeline()
    row = {
        "N": nitrogen,
        "P": phosphorus,
        "K": potassium,
        "soil_moisture": soil_moisture,
        "temperature": temperature_c,
        "humidity": humidity_pct,
        "ph": soil_ph,
        "rainfall": rainfall_mm,
    }
    X = pd.DataFrame([row], columns=FEATURE_ORDER)
    clf = pipeline.named_steps["clf"]
    prep = pipeline.named_steps["prep"]
    classes = np.asarray(clf.classes_)
    Xp = prep.transform(X)

    if hasattr(clf, "predict_proba"):
        proba = clf.predict_proba(Xp)[0]
    else:
        pred = clf.predict(Xp)
        idx = int(np.where(classes == pred[0])[0][0])
        proba = np.zeros(len(classes))
        proba[idx] = 1.0

    order = np.argsort(proba)[::-1]
    ml_ranked = [(str(classes[i]), float(proba[i])) for i in order]

    ranked, factor_notes = hybrid_rank(
        ml_ranked,
        nitrogen=nitrogen,
        phosphorus=phosphorus,
        potassium=potassium,
        soil_moisture=soil_moisture,
        temperature_c=temperature_c,
        humidity_pct=humidity_pct,
        soil_ph=soil_ph,
        rainfall_mm=rainfall_mm,
        soil_type=soil_type or "loam",
        season=season or "season_a",
        top_k=top_k,
    )

    meta = _load_meta()
    version = meta.get("best_model", "unknown")
    explanation = build_explanation(
        row,
        ranked[0][0],
        ranked,
        soil_type=soil_type or "loam",
        season=season or "season_a",
        district=district,
        factor_notes=factor_notes,
    )
    return ranked, explanation, {
        "model_version": f"{version}+agronomy",
        "meta": meta,
        "factor_notes": factor_notes,
    }


def training_dataset_path() -> Path:
    if ACTIVE_DATASET.exists():
        return ACTIVE_DATASET
    return DEFAULT_DATASET
