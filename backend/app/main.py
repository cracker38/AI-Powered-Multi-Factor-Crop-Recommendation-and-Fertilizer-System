import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.ml_service import warmup_pipeline
from app.routers import admin, auth, farmer, predictions

logger = logging.getLogger(__name__)

app = FastAPI(
    title="AgriSmart RW API",
    description="Multi-factor crop & fertilizer recommendations — Firebase, Firestore, ML, Open-Meteo",
    version="1.2.0",
)

# Flutter web: http://localhost:<random_port> → API on :8000
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
    max_age=600,
)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(predictions.router, prefix="/api/v1")
app.include_router(farmer.router, prefix="/api/v1")
app.include_router(admin.router, prefix="/api/v1")


@app.on_event("startup")
def _startup() -> None:
    try:
        model = warmup_pipeline()
        logger.info("ML model preloaded (%s, storage=%s)", model, settings.storage_backend)
    except FileNotFoundError as exc:
        logger.warning("ML model not loaded at startup: %s", exc)


@app.get("/health")
def health():
    return {"status": "ok", "database": settings.storage_backend}
