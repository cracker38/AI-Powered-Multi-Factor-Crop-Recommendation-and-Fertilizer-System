# Quick start (Windows)

Full guide: [README.md](README.md)

## 1. Developer Mode (if Flutter asks for symlinks)

```powershell
start ms-settings:developers
```

Turn **Developer Mode** on → restart PC → new terminal.

## 2. Setup

```powershell
git clone https://github.com/cracker38/AI-Powered-Multi-Factor-Crop-Recommendation-and-Fertilizer-System.git
cd AI-Powered-Multi-Factor-Crop-Recommendation-and-Fertilizer-System
.\scripts\setup-project.ps1

cd backend
copy .env.example .env
# Add firebase-service-account.json, edit .env
.\.venv\Scripts\python.exe scripts\seed_admin.py
```

Enable [Email/Password auth](https://console.firebase.google.com/project/edissaproject/authentication/providers).

## 3. Run

**API**

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\start-api.ps1
```

**App**

```powershell
flutter run -d chrome
```

| Device | API URL |
|--------|---------|
| Web | `http://localhost:8000` |
| Android emulator | `http://10.0.2.2:8000` |
| Phone on LAN | `http://<PC-IP>:8000` |

## Firestore collections

| Collection | Document ID | Contents |
|------------|-------------|----------|
| `users` | Firebase `uid` | email, role, display_name, disabled |
| `predictions` | auto-id | crop results per farmer |
| `training_datasets` | auto-id | CSV metadata (admin) |
| `system` | `model` | ML metadata after training |
