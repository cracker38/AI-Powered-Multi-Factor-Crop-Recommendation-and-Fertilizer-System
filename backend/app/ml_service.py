from __future__ import annotations

import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

from app.agronomy_advisor import FieldConditions, build_agronomy_report
from app.crop_suitability import hybrid_rank

MODEL_DIR = Path(__file__).resolve().parent.parent / "models"
MODEL_PATH = MODEL_DIR / "crop_model.joblib"
META_PATH = MODEL_DIR / "model_meta.json"
ACTIVE_DATASET = MODEL_DIR / "active_dataset.csv"
DEFAULT_DATASET = Path(__file__).resolve().parent.parent.parent / "ml" / "data" / "sample_crop_data.csv"

NUMERIC_FEATURES = ["N", "P", "K", "soil_moisture", "temperature", "humidity", "ph", "rainfall"]
CATEGORICAL_FEATURES = ["soil_type", "season"]
FEATURE_ORDER = NUMERIC_FEATURES + CATEGORICAL_FEATURES


def _load_meta() -> dict:
    if META_PATH.exists():
        return json.loads(META_PATH.read_text(encoding="utf-8"))
    return {}


_pipeline_cache = None


def load_pipeline():
    global _pipeline_cache
    if _pipeline_cache is not None:
        return _pipeline_cache
    if not MODEL_PATH.exists():
        raise FileNotFoundError(
            f"Trained model not found at {MODEL_PATH}. Run: python ml/train.py"
        )
    _pipeline_cache = joblib.load(MODEL_PATH)
    return _pipeline_cache


def warmup_pipeline() -> str:
    """Load ML model once at API startup so first /evaluate is fast."""
    pipe = load_pipeline()
    meta = _load_meta()
    return str(meta.get("best_model", type(pipe.named_steps.get("clf")).__name__))


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
    field = FieldConditions(
        nitrogen=row["N"],
        phosphorus=row["P"],
        potassium=row["K"],
        soil_moisture=row["soil_moisture"],
        temperature_c=row["temperature"],
        humidity_pct=row["humidity"],
        soil_ph=row["ph"],
        rainfall_mm=row["rainfall"],
        soil_type=soil_type,
        season=season,
        district=district,
    )
    return build_agronomy_report(field, ranked, factor_notes).explanation


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
        "soil_type": (soil_type or "loam").lower().strip(),
        "season": (season or "season_a").lower().strip(),
    }
    meta = _load_meta()
    feature_order = meta.get("feature_order", FEATURE_ORDER)
    X = pd.DataFrame([{k: row[k] for k in feature_order}], columns=feature_order)
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

    version = meta.get("best_model", "unknown")
    field = FieldConditions(
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
        district=district,
    )
    report = build_agronomy_report(field, ranked, factor_notes)
    explanation = report.explanation
    return ranked, explanation, {
        "model_version": f"{version}+adss",
        "meta": meta,
        "factor_notes": factor_notes,
        "environment_analysis": report.environment_analysis,
        "precision_notes_adss": report.precision_notes,
        "fertilizer_applicable": report.fertilizer_applicable,
    }


def training_dataset_path() -> Path:
    if ACTIVE_DATASET.exists():
        return ACTIVE_DATASET
    return DEFAULT_DATASET
