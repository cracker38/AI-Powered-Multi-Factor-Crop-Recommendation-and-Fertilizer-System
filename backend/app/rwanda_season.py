"""Rwanda agricultural seasons from calendar date (Kigali / national convention)."""
from __future__ import annotations

from datetime import date, datetime, timezone

SEASON_A = "season_a"  # Sep-Jan — short rains
SEASON_B = "season_b"  # Feb-Jun — long rains
SEASON_C = "season_c"  # Jul-Aug — dry season

SEASON_INFO: dict[str, dict[str, str]] = {
    SEASON_A: {
        "label": "Season A — Short rains (Sep–Jan)",
        "months": "September to January",
        "advice": "Plant at the start of the short rains; ensure drainage on heavy soils.",
    },
    SEASON_B: {
        "label": "Season B — Long rains (Feb–Jun)",
        "months": "February to June",
        "advice": "Main cropping window — complete basal fertilizer and timely weeding.",
    },
    SEASON_C: {
        "label": "Season C — Dry season (Jul–Aug)",
        "months": "July to August",
        "advice": "Favour drought-tolerant crops or irrigation; conserve soil moisture with mulch.",
    },
}


def rwanda_season_for_month(month: int) -> str:
    """Return season id for month 1-12."""
    if month in (9, 10, 11, 12, 1):
        return SEASON_A
    if month in (2, 3, 4, 5, 6):
        return SEASON_B
    return SEASON_C


def current_rwanda_season(when: date | datetime | None = None) -> str:
    if when is None:
        when = datetime.now(timezone.utc)
    if isinstance(when, datetime):
        month = when.month
    else:
        month = when.month
    return rwanda_season_for_month(month)


def season_label(season_id: str) -> str:
    return SEASON_INFO.get(season_id, {}).get("label", season_id.replace("_", " ").title())
