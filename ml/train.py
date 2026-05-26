"""Train crop ML models; writes to backend/models/."""
from __future__ import annotations

import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, precision_recall_fscore_support
from sklearn.model_selection import train_test_split
from sklearn.neighbors import KNeighborsClassifier
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeClassifier

ROOT = Path(__file__).resolve().parent
ACTIVE_DATASET = ROOT.parent / "backend" / "models" / "active_dataset.csv"
DATA_CSV = ACTIVE_DATASET if ACTIVE_DATASET.exists() else ROOT / "data" / "sample_crop_data.csv"
MODEL_DIR = ROOT.parent / "backend" / "models"
MODEL_PATH = MODEL_DIR / "crop_model.joblib"
META_PATH = MODEL_DIR / "model_meta.json"

FEATURES = ["N", "P", "K", "soil_moisture", "temperature", "humidity", "ph", "rainfall"]
LABEL = "label"


def evaluate(y_true, y_pred, labels):
    acc = accuracy_score(y_true, y_pred)
    p, r, f1, _ = precision_recall_fscore_support(y_true, y_pred, average="weighted", zero_division=0)
    report = classification_report(y_true, y_pred, zero_division=0)
    return {
        "accuracy": float(acc),
        "precision_weighted": float(p),
        "recall_weighted": float(r),
        "f1_weighted": float(f1),
        "classification_report": report,
        "labels": labels,
    }


def build_pipelines(random_state: int = 42):
    pre = ColumnTransformer([("scale", StandardScaler(), FEATURES)], remainder="drop")
    return {
        "random_forest": Pipeline([
            ("prep", pre),
            ("clf", RandomForestClassifier(n_estimators=200, random_state=random_state, class_weight="balanced")),
        ]),
        "decision_tree": Pipeline([
            ("prep", pre),
            ("clf", DecisionTreeClassifier(max_depth=12, random_state=random_state, class_weight="balanced")),
        ]),
        "knn": Pipeline([
            ("prep", pre),
            ("clf", KNeighborsClassifier(n_neighbors=5, weights="distance")),
        ]),
    }


def main():
    df = pd.read_csv(DATA_CSV).dropna()
    for c in FEATURES:
        df[c] = pd.to_numeric(df[c], errors="coerce")
    df = df.dropna()
    X, y = df[FEATURES], df[LABEL]
    try:
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.25, random_state=42, stratify=y)
    except ValueError:
        X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.25, random_state=42)

    best_name, best_acc, best_pipe = None, -1.0, None
    results = {}
    for name, pipe in build_pipelines().items():
        pipe.fit(X_train, y_train)
        metrics = evaluate(y_test, pipe.predict(X_test), sorted(y.unique().tolist()))
        results[name] = metrics
        if metrics["accuracy"] > best_acc:
            best_acc, best_name, best_pipe = metrics["accuracy"], name, pipe

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(best_pipe, MODEL_PATH)
    meta = {
        "best_model": best_name,
        "feature_order": FEATURES,
        "data_source": str(DATA_CSV),
        "all_metrics": {k: {m: v[m] for m in ("accuracy", "precision_weighted", "recall_weighted", "f1_weighted")} for k, v in results.items()},
    }
    META_PATH.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(f"Saved {best_name} accuracy={best_acc:.4f} -> {MODEL_PATH}")


if __name__ == "__main__":
    main()
