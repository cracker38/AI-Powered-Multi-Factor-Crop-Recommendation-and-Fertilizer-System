"""Approximate coordinates for Rwanda districts (Open-Meteo)."""
from __future__ import annotations

# lat, lon — capital towns / district centers
DISTRICT_COORDS: dict[str, tuple[float, float]] = {
    "bugesera": (-2.1667, 30.1667),
    "burera": (-1.5833, 29.7500),
    "gakenke": (-1.7000, 29.8500),
    "gasabo": (-1.9200, 30.1100),
    "gatsibo": (-1.4333, 30.4333),
    "kayonza": (-1.8500, 30.6167),
    "kicukiro": (-1.9833, 30.1167),
    "kirehe": (-2.5000, 30.7833),
    "muhanga": (-2.0833, 29.7500),
    "musanze": (-1.5000, 29.6333),
    "ngoma": (-2.1833, 30.4500),
    "ngororero": (-1.8667, 29.6500),
    "nyabihu": (-1.6833, 29.5167),
    "nyagatare": (-1.3000, 30.3167),
    "nyamagabe": (-2.4833, 29.5500),
    "nyanza": (-2.3500, 29.7500),
    "nyarugenge": (-1.9500, 30.0600),
    "rubavu": (-1.6833, 29.2333),
    "ruhango": (-2.2500, 29.7500),
    "rulindo": (-1.8000, 29.9167),
    "rusizi": (-2.4833, 28.9000),
    "rutsiro": (-2.0833, 29.3333),
    "rwamagana": (-1.9500, 30.4333),
}

DEFAULT_COORDS = (-1.9403, 30.0588)  # Kigali


def coords_for_district(district: str | None) -> tuple[float, float]:
    if not district:
        return DEFAULT_COORDS
    key = district.lower().strip().replace(" ", "_")
    if key in DISTRICT_COORDS:
        return DISTRICT_COORDS[key]
    for name, coord in DISTRICT_COORDS.items():
        if name in key or key in name:
            return coord
    return DEFAULT_COORDS
