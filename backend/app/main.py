from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import admin, auth, farmer, predictions

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


@app.get("/health")
def health():
    return {"status": "ok", "database": settings.storage_backend}
