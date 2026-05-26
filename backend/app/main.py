from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import admin, auth, farmer, predictions

app = FastAPI(
    title="AgriSmart RW API",
    description="Multi-factor crop & fertilizer recommendations — Firebase, Firestore, ML, Open-Meteo",
    version="1.2.0",
)

# Flutter web runs on http://localhost:<random_port> — regex allows any dev port.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["*"],
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
    return {"status": "ok", "database": "firestore"}
