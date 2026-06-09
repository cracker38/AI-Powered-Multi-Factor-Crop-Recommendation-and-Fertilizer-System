"""OpenWeatherMap + Open-Meteo live climate for Rwanda districts."""
from __future__ import annotations

import time
from datetime import datetime, timezone
from typing import Any

import requests

from app.config import settings
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

_FORECAST_CACHE: dict[str, tuple[float, dict[str, Any]]] = {}
_CLIMATE_CACHE: dict[str, tuple[float, dict[str, Any]]] = {}
_FORECAST_TTL_SEC = 1800
_CLIMATE_TTL_SEC = 900  # 15 min — live readings


def _district_key(district: str | None) -> str:
    return (district or "kigali").lower().strip()


def fetch_openweather_climate(district: str | None) -> dict[str, Any]:
    """Current temp/humidity + 5-day rain forecast from OpenWeatherMap."""
    api_key = (settings.openweather_api_key_resolved or "").strip()
    if not api_key:
        return {"available": False, "reason": "OPENWEATHER_API_KEY not configured"}

    cache_key = f"owm:{_district_key(district)}"
    now = time.time()
    cached = _CLIMATE_CACHE.get(cache_key)
    if cached and now - cached[0] < _CLIMATE_TTL_SEC:
        return cached[1]

    lat, lon = coords_for_district(district)
    empty: dict[str, Any] = {
        "available": False,
        "district": district or "Kigali",
        "latitude": lat,
        "longitude": lon,
    }
    try:
        current = requests.get(
            "https://api.openweathermap.org/data/2.5/weather",
            params={"lat": lat, "lon": lon, "appid": api_key, "units": "metric"},
            timeout=8,
        )
        current.raise_for_status()
        c = current.json()
        main = c.get("main") or {}
        temp = float(main.get("temp", 0))
        humidity = float(main.get("humidity", 0))
        rain_now = c.get("rain") or {}
        recent_mm = float(rain_now.get("1h") or rain_now.get("3h", 0) or 0)

        forecast = requests.get(
            "https://api.openweathermap.org/data/2.5/forecast",
            params={"lat": lat, "lon": lon, "appid": api_key, "units": "metric"},
            timeout=8,
        )
        forecast.raise_for_status()
        f = forecast.json()
        rain_5d = 0.0
        for item in (f.get("list") or [])[:40]:
            rain_5d += float((item.get("rain") or {}).get("3h", 0) or 0)

        # Scale 5-day forecast to ~7-day rainfall context for the crop model
        rainfall_mm = round(max(rain_5d * 7 / 5, recent_mm), 1)
        if rainfall_mm <= 0 and recent_mm > 0:
            rainfall_mm = round(recent_mm * 24, 1)

        result = {
            "available": True,
            "temperature_c": round(temp, 1),
            "humidity_pct": round(humidity, 1),
            "rainfall_mm": rainfall_mm,
            "recent_rain_mm": round(recent_mm, 1),
            "forecast_rain_5d_mm": round(rain_5d, 1),
            "district": district or "Kigali",
            "latitude": lat,
            "longitude": lon,
            "source": "OpenWeatherMap",
            "provider_url": "https://openweathermap.org/",
            "fetched_at": datetime.now(timezone.utc).isoformat(),
            "note": (
                f"Live conditions for {district or 'Kigali'}: {temp:.1f}°C, "
                f"{humidity:.0f}% humidity, ~{rainfall_mm:.0f} mm rainfall (7-day estimate from forecast)."
            ),
        }
        _CLIMATE_CACHE[cache_key] = (now, result)
        return result
    except Exception as exc:
        empty["reason"] = str(exc)
        return empty


def fetch_live_forecast(district: str | None) -> dict[str, Any]:
    """Open-Meteo 7-day forecast; cached per district (fallback + forecast charts)."""
    cache_key = f"meteo:{_district_key(district)}"
    now = time.time()
    cached = _FORECAST_CACHE.get(cache_key)
    if cached and now - cached[0] < _FORECAST_TTL_SEC:
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
        _FORECAST_CACHE[cache_key] = (now, result)
        return result
    except Exception:
        return empty


def get_live_field_climate(district: str | None) -> dict[str, Any]:
    """
    Auto climate for crop analysis: OpenWeatherMap first, Open-Meteo fallback.
    Returns temperature (°C), humidity (%), rainfall_mm (7-day context).
    """
    owm = fetch_openweather_climate(district)
    if owm.get("available"):
        meteo = fetch_live_forecast(district)
        if meteo.get("live_available"):
            fp7 = meteo.get("forecast_precipitation_mm_7d")
            if fp7 is not None and float(fp7) > float(owm.get("rainfall_mm", 0)):
                owm = {**owm, "rainfall_mm": round(float(fp7), 1), "rainfall_blended": True}
            owm["forecast_daily"] = meteo.get("forecast_daily") or []
            owm["secondary_source"] = meteo.get("live_data_source", "Open-Meteo")
        return owm

    meteo = fetch_live_forecast(district)
    if meteo.get("live_available"):
        return {
            "available": True,
            "temperature_c": meteo["live_temperature_c"],
            "humidity_pct": meteo["live_humidity_pct"],
            "rainfall_mm": meteo.get("forecast_precipitation_mm_7d") or 0,
            "district": district or "Kigali",
            "source": "Open-Meteo (Meteo Rwanda region model)",
            "provider_url": "https://open-meteo.com/",
            "fetched_at": datetime.now(timezone.utc).isoformat(),
            "forecast_daily": meteo.get("forecast_daily") or [],
            "note": "OpenWeather unavailable — using Open-Meteo for Rwanda district coordinates.",
        }

    return {
        "available": False,
        "district": district or "Kigali",
        "reason": owm.get("reason", "Weather APIs unavailable"),
    }


def apply_live_climate(
    *,
    district: str | None,
    temperature_c: float,
    humidity_pct: float,
    rainfall_mm: float,
    use_live: bool = True,
) -> tuple[float, float, float, dict[str, Any]]:
    """Replace manual climate inputs with live API readings when enabled."""
    meta: dict[str, Any] = {"applied": False}
    if not use_live:
        return temperature_c, humidity_pct, rainfall_mm, meta
    live = get_live_field_climate(district)
    if not live.get("available"):
        meta["live_error"] = live.get("reason", "unavailable")
        return temperature_c, humidity_pct, rainfall_mm, meta
    meta = {
        "applied": True,
        "source": live.get("source"),
        "provider_url": live.get("provider_url"),
        "district": live.get("district"),
        "fetched_at": live.get("fetched_at"),
        "note": live.get("note"),
    }
    return (
        float(live["temperature_c"]),
        float(live["humidity_pct"]),
        float(live["rainfall_mm"]),
        meta,
    )


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
        climate = get_live_field_climate(district)
        if climate.get("available"):
            live["climate_source"] = climate.get("source")
            live["climate_note"] = climate.get("note")
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

    forecast_note = "Climate inputs are loaded automatically from live weather APIs for your district. "
    if live.get("climate_source"):
        forecast_note += f"Primary source: {live['climate_source']}. "
    if live.get("live_available"):
        forecast_note += "7-day outlook from Open-Meteo (Rwanda grid) is included."
    else:
        forecast_note += "Extended forecast unavailable — using current readings and seasonal guidance."

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
