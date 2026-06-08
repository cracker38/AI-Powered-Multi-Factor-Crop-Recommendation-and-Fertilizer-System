"""Seasonal guidance + live Open-Meteo forecast for Rwanda districts."""
from __future__ import annotations

import time
from typing import Any

import requests

from app.rwanda_coords import coords_for_district

SEASON_INFO = {
    "season_a": {
        "name": "Season A (Short rains)",
        "months": "September – January",
        "rainfall": "Moderate to high rainfall; main planting window for many crops.",
        "advice": "Plan drainage for heavy rains; ideal for maize, beans, and vegetables.",
    },
    "season_b": {
        "name": "Season B (Long rains)",
        "months": "February – June",
        "rainfall": "Primary rainy season with reliable moisture.",
        "advice": "Best period for maize, rice in wetlands, and root crops; monitor fungal diseases.",
    },
    "season_c": {
        "name": "Season C (Dry season)",
        "months": "July – August",
        "rainfall": "Lower rainfall; irrigation may be required.",
        "advice": "Focus on drought-tolerant crops; conserve soil moisture with mulch.",
    },
}

DISTRICT_CLIMATE: dict[str, str] = {
    "musanze": "Cooler highland climate — suitable for potatoes, pyrethrum, and temperate vegetables.",
    "rubavu": "Lake Kivu zone — moderate temperatures, high humidity.",
    "huye": "Southern highlands — bimodal rainfall pattern.",
    "nyagatare": "Eastern savanna — lower rainfall; drought-tolerant crops recommended.",
    "kayonza": "Eastern province — variable rainfall; irrigation planning advised in dry spells.",
}

_CACHE: dict[str, tuple[float, dict[str, Any]]] = {}
_CACHE_TTL_SEC = 1800  # 30 minutes


def fetch_live_forecast(district: str | None) -> dict[str, Any]:
    """Open-Meteo 7-day forecast; cached per district."""
    cache_key = (district or "kigali").lower().strip()
    now = time.time()
    cached = _CACHE.get(cache_key)
    if cached and now - cached[0] < _CACHE_TTL_SEC:
        return cached[1]

    lat, lon = coords_for_district(district)
    empty: dict[str, Any] = {
        "live_available": False,
        "live_temperature_c": None,
        "live_humidity_pct": None,
        "forecast_precipitation_mm_7d": None,
        "forecast_daily": [],
        "live_data_source": "",
    }
    try:
        url = "https://api.open-meteo.com/v1/forecast"
        params = {
            "latitude": lat,
            "longitude": lon,
            "current": "temperature_2m,relative_humidity_2m,precipitation",
            "daily": "precipitation_sum,temperature_2m_max,temperature_2m_min",
            "forecast_days": 7,
            "timezone": "Africa/Kigali",
        }
        r = requests.get(url, params=params, timeout=4)
        r.raise_for_status()
        data = r.json()
        current = data.get("current") or {}
        daily = data.get("daily") or {}
        dates = daily.get("time") or []
        precip = daily.get("precipitation_sum") or []
        tmax = daily.get("temperature_2m_max") or []
        tmin = daily.get("temperature_2m_min") or []
        daily_rows = []
        total_precip = 0.0
        for i, d in enumerate(dates[:7]):
            p = float(precip[i]) if i < len(precip) and precip[i] is not None else 0.0
            total_precip += p
            daily_rows.append(
                {
                    "date": d,
                    "precipitation_mm": round(p, 1),
                    "temp_max_c": round(float(tmax[i]), 1) if i < len(tmax) and tmax[i] is not None else None,
                    "temp_min_c": round(float(tmin[i]), 1) if i < len(tmin) and tmin[i] is not None else None,
                }
            )
        result = {
            "live_available": True,
            "live_temperature_c": round(float(current.get("temperature_2m", 0)), 1),
            "live_humidity_pct": round(float(current.get("relative_humidity_2m", 0)), 1),
            "forecast_precipitation_mm_7d": round(total_precip, 1),
            "forecast_daily": daily_rows,
            "live_data_source": f"Open-Meteo ({lat:.2f}, {lon:.2f})",
        }
        _CACHE[cache_key] = (now, result)
        return result
    except Exception:
        return empty


def weather_insight(
    *,
    season: str,
    district: str | None,
    rainfall_mm: float,
    temperature_c: float,
    humidity_pct: float,
    use_live_api: bool = True,
) -> dict:
    s = (season or "season_a").lower()
    info = SEASON_INFO.get(s, SEASON_INFO["season_a"])
    district_note = ""
    if district:
        key = district.lower().replace(" ", "_")
        for k, v in DISTRICT_CLIMATE.items():
            if k in key:
                district_note = v
                break
        if not district_note:
            district_note = f"Location: {district} — align crop choice with local extension officer advice."

    alerts: list[str] = []
    if rainfall_mm < 80:
        alerts.append("Recorded rainfall is low — consider supplemental irrigation or drought-resistant varieties.")
    elif rainfall_mm > 280:
        alerts.append("High rainfall — ensure field drainage and disease monitoring.")
    if temperature_c > 32:
        alerts.append("High temperature stress possible — irrigate during peak heat; mulch soil.")
    elif temperature_c < 12:
        alerts.append("Cool conditions — select cold-tolerant varieties and adjust planting dates.")
    if humidity_pct > 88:
        alerts.append("Very high humidity — increased risk of fungal diseases; spacing and fungicide as needed.")

    live: dict[str, Any] = {}
    if use_live_api:
        live = fetch_live_forecast(district)
        if live.get("live_available"):
            lt = live.get("live_temperature_c")
            lh = live.get("live_humidity_pct")
            fp7 = live.get("forecast_precipitation_mm_7d")
            if lt is not None and lt > 32:
                alerts.append(f"Live forecast: high temperature ({lt}°C) — plan irrigation.")
            if fp7 is not None and fp7 < 15:
                alerts.append(f"Live 7-day forecast: low rain ({fp7} mm) — monitor soil moisture.")
            elif fp7 is not None and fp7 > 80:
                alerts.append(f"Live 7-day forecast: heavy rain ({fp7} mm) — check drainage.")

    forecast_note = (
        "Recommendations combine your field readings with Rwanda seasonal patterns. "
    )
    if live.get("live_available"):
        forecast_note += "Live weather from Open-Meteo is included for your district."
    else:
        forecast_note += "Live forecast unavailable — using seasonal guidance only."

    return {
        "season_name": info["name"],
        "season_months": info["months"],
        "seasonal_rainfall": info["rainfall"],
        "seasonal_advice": info["advice"],
        "district_note": district_note,
        "alerts": alerts,
        "forecast_note": forecast_note,
        **live,
    }
