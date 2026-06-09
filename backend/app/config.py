from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(_BACKEND_DIR / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    firebase_credentials_path: str = "./firebase-service-account.json"
    firebase_project_id: str = "edissaproject"
    firebase_web_api_key: str = "AIzaSyAhqYyWDFv1jeG5NDRDURo9IZV44JQFx9s"
    admin_email: str = "uwayiedissa@gmail.com"
    admin_password: str = ""
    database_url: str = "sqlite:///./crops_recommendation.db"
    # Use sqlite when Firestore gRPC hangs (common on Windows). Set firestore for cloud-only deploy.
    storage_backend: str = "sqlite"
    openweather_api_key: str = ""

    @property
    def openweather_api_key_resolved(self) -> str:
        raw = (self.openweather_api_key or "").strip()
        if raw.startswith("b64:"):
            import base64

            try:
                return base64.b64decode(raw[4:]).decode("utf-8").strip()
            except Exception:
                return ""
        return raw

    @property
    def admin_email_normalized(self) -> str:
        return self.admin_email.strip().lower()


settings = Settings()
