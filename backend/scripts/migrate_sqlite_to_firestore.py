"""One-time migration from crops_recommendation.db to Firestore."""
from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.firestore_db import create_prediction, upsert_user

DB = Path(__file__).resolve().parent.parent / "crops_recommendation.db"


def main() -> None:
    if not DB.exists():
        print("No SQLite database found — nothing to migrate.")
        return
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    users = conn.execute("SELECT * FROM users").fetchall()
    for u in users:
        upsert_user(
            u["firebase_uid"],
            email=u["email"],
            display_name=u["display_name"],
            role=u["role"],
            disabled=bool(u["disabled"]),
        )
        print(f"Migrated user {u['email']}")
    preds = conn.execute("SELECT p.*, u.firebase_uid FROM crop_predictions p JOIN users u ON p.user_id = u.id").fetchall()
    for p in preds:
        create_prediction(
            p["firebase_uid"],
            {
                "nitrogen": p["nitrogen"],
                "phosphorus": p["phosphorus"],
                "potassium": p["potassium"],
                "soil_moisture": p["soil_moisture"],
                "temperature_c": p["temperature_c"],
                "humidity_pct": p["humidity_pct"],
                "soil_ph": p["soil_ph"],
                "rainfall_mm": p["rainfall_mm"],
                "model_version": p["model_version"],
                "top_crop": p["top_crop"],
                "top_confidence": p["top_confidence"],
                "explanation": p["explanation"],
                "full_ranking": [],
            },
        )
    print(f"Migrated {len(users)} users, {len(preds)} predictions.")


if __name__ == "__main__":
    main()
