# Quick start (collaborators)

Full guide: **[README.md](README.md)**

## 1. Developer Mode (Windows)

```powershell
start ms-settings:developers
```

Turn on → restart PC.

## 2. Clone & setup

```powershell
git clone https://github.com/cracker38/AI-Powered-Multi-Factor-Crop-Recommendation-and-Fertilizer-System.git
cd AI-Powered-Multi-Factor-Crop-Recommendation-and-Fertilizer-System
.\scripts\setup-project.ps1
cd backend
.\.venv\Scripts\python.exe scripts\seed_admin.py
```

`backend/.env` and Firebase Admin JSON are **already in the repo**.

Admin login: see `ADMIN_EMAIL` and `ADMIN_PASSWORD` in `backend/.env`.

## 3. Run (two terminals)

**API**

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-api.ps1
```

**App**

```powershell
flutter run -d chrome
```

| Device | API |
|--------|-----|
| Web | `http://localhost:8000` |
| Android emulator | `http://10.0.2.2:8000` |
