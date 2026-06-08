"""Run Firestore operations with a deadline so HTTP handlers do not hang."""
from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeout
from typing import TypeVar

from fastapi import HTTPException

from app.config import settings

T = TypeVar("T")

_DEFAULT_TIMEOUT_SEC = 10.0


def run_firestore(label: str, fn, *args, timeout_sec: float = _DEFAULT_TIMEOUT_SEC, **kwargs) -> T:
    if settings.storage_backend == "sqlite":
        return fn(*args, **kwargs)
    with ThreadPoolExecutor(max_workers=1) as pool:
        fut = pool.submit(fn, *args, **kwargs)
        try:
            return fut.result(timeout=timeout_sec)
        except FuturesTimeout:
            raise HTTPException(
                status_code=503,
                detail=(
                    f"Firestore timed out during {label}. Check network and "
                    "backend/edissaproject-firebase-adminsdk-fbsvc-b718f54352.json, then restart the API."
                ),
            ) from None
