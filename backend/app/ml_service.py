from __future__ import annotations

import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

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


def build_explanation(row: dict, top: str, ranked: list[tuple[str, float]]) -> str:
    parts = [
        f"Primary recommendation is {top} ({ranked[0][1] * 100:.1f}% confidence) "
        "based on your soil and climate profile."
    ]
    ph = row["ph"]
    if ph < 6.0:
        parts.append("Soil pH is acidic; liming may help broaden crop options.")
    elif ph > 7.8:
        parts.append("Soil pH is alkaline; choose tolerant varieties.")
    else:
        parts.append("Soil pH is in a moderate range for many crops.")

    if row["N"] < 40:
        parts.append("Nitrogen appears limited; consider legume rotation or staged N application.")
    if row["P"] < 40:
        parts.append("Phosphorus may limit early root development.")
    if row["K"] < 40:
        parts.append("Potassium is on the lower side for drought resilience.")

    if row["rainfall"] < 100:
        parts.append("Rainfall is relatively low; prioritize drought-tolerant crops.")
    elif row["rainfall"] > 250:
        parts.append("High rainfall; plan drainage and disease management.")

    if row["soil_moisture"] < 35:
        parts.append("Low soil moisture; confirm irrigation with field observation.")
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

    order = np.argsort(proba)[::-1][:top_k]
    ranked = [(str(classes[i]), float(proba[i])) for i in order]
    meta = _load_meta()
    version = meta.get("best_model", "unknown")
    explanation = build_explanation(row, ranked[0][0], ranked)
    return ranked, explanation, {"model_version": version, "meta": meta}


def training_dataset_path() -> Path:
    if ACTIVE_DATASET.exists():
        return ACTIVE_DATASET
    return DEFAULT_DATASET
