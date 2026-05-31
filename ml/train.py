"""Train crop ML models; writes to backend/models/."""
from __future__ import annotations

import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.metrics import accuracy_score, classification_report, precision_recall_fscore_support
from sklearn.model_selection import cross_val_score, train_test_split
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
            ("clf", RandomForestClassifier(
                n_estimators=300,
                max_depth=14,
                min_samples_leaf=2,
                random_state=random_state,
                class_weight="balanced",
            )),
        ]),
        "gradient_boosting": Pipeline([
            ("prep", pre),
            ("clf", GradientBoostingClassifier(
                n_estimators=150,
                max_depth=5,
                learning_rate=0.08,
                random_state=random_state,
            )),
        ]),
        "decision_tree": Pipeline([
            ("prep", pre),
            ("clf", DecisionTreeClassifier(max_depth=12, random_state=random_state, class_weight="balanced")),
        ]),
        "knn": Pipeline([
            ("prep", pre),
            ("clf", KNeighborsClassifier(n_neighbors=7, weights="distance")),
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
        n_splits = min(3, min(y_train.value_counts()))
        cv = cross_val_score(pipe, X_train, y_train, cv=max(2, n_splits), scoring="accuracy") if n_splits >= 2 else np.array([0.0])
        pipe.fit(X_train, y_train)
        metrics = evaluate(y_test, pipe.predict(X_test), sorted(y.unique().tolist()))
        metrics["cv_accuracy_mean"] = float(cv.mean())
        results[name] = metrics
        score = metrics["accuracy"] * 0.6 + metrics["cv_accuracy_mean"] * 0.4
        if score > best_acc:
            best_acc, best_name, best_pipe = score, name, pipe

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(best_pipe, MODEL_PATH)
    # Sync training CSV to active dataset
    df.to_csv(ACTIVE_DATASET, index=False)
    meta = {
        "best_model": best_name,
        "feature_order": FEATURES,
        "data_source": str(DATA_CSV),
        "hybrid_agronomy": True,
        "all_metrics": {
            k: {m: v[m] for m in ("accuracy", "precision_weighted", "recall_weighted", "f1_weighted", "cv_accuracy_mean")}
            for k, v in results.items()
        },
    }
    META_PATH.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    print(f"Saved {best_name} test_acc={results[best_name]['accuracy']:.4f} -> {MODEL_PATH}")


if __name__ == "__main__":
    main()
