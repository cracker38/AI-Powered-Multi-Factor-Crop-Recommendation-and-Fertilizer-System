"""Run SOIL7In_one_9b demo logic on PC -> Firebase Realtime Database."""
from __future__ import annotations

import json
import random
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

API_KEY = "AIzaSyAhqYyWDFv1jeG5NDRDURo9IZV44JQFx9s"
AUTH_TRIES = [
    ("uwayiedissa@gmail.com", "Edissa@123"),
]
DEVICE_ID = "ESP8266_SOIL_01"

DB_URLS = [
    "https://edissaproject-default-rtdb.firebaseio.com",
    "https://edissaproject-default-rtdb.europe-west1.firebasedatabase.app",
]

DEMO_FARMS = [
    {
        "label": "Kigali maize",
        "district": "kigali",
        "soil_type": "loam",
        "season": "season_b",
        "temperature_c": 24.2,
        "humidity_pct": 72.0,
        "soil_moisture": 58.0,
        "nitrogen": 90.0,
        "phosphorus": 42.0,
        "potassium": 43.0,
        "ph": 6.5,
        "ec_us_cm": 850.0,
        "rainfall_mm": 680.0,
    },
    {
        "label": "Musanze potato",
        "district": "musanze",
        "soil_type": "volcanic",
        "season": "season_a",
        "temperature_c": 18.5,
        "humidity_pct": 78.0,
        "soil_moisture": 62.0,
        "nitrogen": 110.0,
        "phosphorus": 55.0,
        "potassium": 180.0,
        "ph": 5.8,
        "ec_us_cm": 1200.0,
        "rainfall_mm": 920.0,
    },
    {
        "label": "Nyagatare cassava",
        "district": "nyagatare",
        "soil_type": "sandy",
        "season": "season_c",
        "temperature_c": 28.0,
        "humidity_pct": 55.0,
        "soil_moisture": 38.0,
        "nitrogen": 65.0,
        "phosphorus": 28.0,
        "potassium": 52.0,
        "ph": 6.2,
        "ec_us_cm": 620.0,
        "rainfall_mm": 420.0,
    },
]


def drift(value: float, span: float) -> float:
    return round(value + random.uniform(-span, span), 2)


def build_packet(farm: dict, seq: int) -> dict:
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {
        "device_id": DEVICE_ID,
        "source": "demo",
        "sequence": seq,
        "label": farm["label"],
        "district": farm["district"],
        "soil_type": farm["soil_type"],
        "season": farm["season"],
        "temperature_c": drift(farm["temperature_c"], 1.8),
        "humidity_pct": drift(farm["humidity_pct"], 2.5),
        "soil_moisture": drift(farm["soil_moisture"], 3.0),
        "nitrogen": drift(farm["nitrogen"], 2.0),
        "phosphorus": drift(farm["phosphorus"], 1.5),
        "potassium": drift(farm["potassium"], 2.0),
        "ph": round(drift(farm["ph"], 0.12), 2),
        "ec_us_cm": drift(farm["ec_us_cm"], 40),
        "rainfall_mm": drift(farm["rainfall_mm"], 18),
        "online": True,
        "updated_at": ts,
        "updated_at_ms": int(time.time() * 1000),
    }


def http_json(method: str, url: str, body: dict | None = None) -> tuple[int, dict | str]:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    headers = {"Content-Type": "application/json"} if body is not None else {}
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=25) as res:
            raw = res.read().decode("utf-8")
            return res.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, raw


def sign_in() -> str:
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}"
    last = ""
    for email, password in AUTH_TRIES:
        code, resp = http_json("POST", url, {
            "email": email,
            "password": password,
            "returnSecureToken": True,
        })
        if code == 200 and isinstance(resp, dict) and resp.get("idToken"):
            print(f"[Auth] signed in as {email}")
            return resp["idToken"]
        last = str(resp)
        print(f"[Auth] failed for {email} HTTP {code}")
    raise RuntimeError(f"Firebase login failed for all accounts. Last: {last}")


def pick_db_url(token: str) -> str:
    for base in DB_URLS:
        code, _ = http_json("GET", f"{base}/.json?auth={token}&shallow=true")
        print(f"[RTDB] probe {base} -> HTTP {code}")
        if code == 200:
            return base
    raise RuntimeError("Realtime Database not found. Create it in Firebase Console.")


def rtdb_put(base: str, token: str, path: str, payload: dict) -> None:
    code, resp = http_json("PUT", f"{base}{path}.json?auth={token}", payload)
    if code != 200:
        raise RuntimeError(f"PUT {path} failed HTTP {code}: {resp}")


def rtdb_post(base: str, token: str, path: str, payload: dict) -> None:
    code, resp = http_json("POST", f"{base}{path}.json?auth={token}", payload)
    if code != 200:
        raise RuntimeError(f"POST {path} failed HTTP {code}: {resp}")


def main() -> int:
    print("=== AgriSmart RW | SOIL demo -> Firebase RTDB ===")
    token = sign_in()
    db_base = pick_db_url(token)
    path_base = f"/soil_sensors/{DEVICE_ID}"

    for i, farm in enumerate(DEMO_FARMS, start=1):
        pkt = build_packet(farm, i)
        rtdb_put(db_base, token, f"{path_base}/history/demo_{i}", pkt)
        print(f"[RTDB] seed demo_{i} OK - {farm['label']}")

    rtdb_put(db_base, token, "/demo/latest", {
        "source": "demo",
        "message": "AgriSmart RW - 3 Rwanda demo farms loaded",
        "device_id": DEVICE_ID,
    })

    for cycle in range(1, 4):
        farm = DEMO_FARMS[(cycle - 1) % len(DEMO_FARMS)]
        pkt = build_packet(farm, 100 + cycle)
        rtdb_put(db_base, token, f"{path_base}/latest", pkt)
        rtdb_post(db_base, token, f"{path_base}/history", pkt)
        rtdb_put(db_base, token, f"{path_base}/meta", {
            "device_id": DEVICE_ID,
            "last_sequence": pkt["sequence"],
            "last_upload": pkt["updated_at"],
            "mode": "demo",
        })
        print(f"[RTDB] cycle {cycle} OK - {farm['label']}")
        if cycle < 3:
            time.sleep(5)

    print(f"\nDone. Firebase Console -> Realtime Database -> soil_sensors/{DEVICE_ID}/latest")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
