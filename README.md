# AI-Powered Multi-Factor Crop Recommendation and Fertilizer System

**AgriSmart RW** — precision agriculture for Rwanda. ML crop rankings, fertilizer plans, soil health, district weather, and admin tools for farmers and extension staff.

| Layer | Technology |
|-------|------------|
| App | Flutter (Web, Windows, Android, iOS) |
| Auth & data | Firebase Auth + Cloud Firestore |
| API & ML | Python FastAPI + scikit-learn |
| Weather | Open-Meteo (free, no API key) |

**Repository:** https://github.com/cracker38/AI-Powered-Multi-Factor-Crop-Recommendation-and-Fertilizer-System

---

## For collaborators — run in 5 minutes

This is a **private team repo**. Configuration and Firebase credentials are **already in Git** so you do not need to create `.env` or download keys manually.

### Checklist

| Step | Command / action |
|------|------------------|
| 1 | Install [Flutter](https://docs.flutter.dev/get-started/install/windows), [Python 3.10+](https://www.python.org/downloads/), [Git](https://git-scm.com/download/win) |
| 2 | **Windows:** enable [Developer Mode](#windows-developer-mode-required) (fixes Flutter symlink error) |
| 3 | Clone and enter the project (see below) |
| 4 | `.\scripts\setup-project.ps1` |
| 5 | `cd backend` → `.\.venv\Scripts\python.exe scripts\seed_admin.py` |
| 6 | Start API + Flutter (two terminals, see [Run](#run-the-application)) |
| 7 | Log in as **admin** using `ADMIN_EMAIL` / `ADMIN_PASSWORD` in `backend/.env` |

### Clone

```powershell
git clone https://github.com/cracker38/AI-Powered-Multi-Factor-Crop-Recommendation-and-Fertilizer-System.git
cd AI-Powered-Multi-Factor-Crop-Recommendation-and-Fertilizer-System
git pull
```

### Files included for you (no manual Firebase download)

| File | Purpose |
|------|---------|
| `backend/.env` | API keys, admin email/password, DB path |
| `backend/edissaproject-firebase-adminsdk-fbsvc-eae48edf0e.json` | Firebase Admin SDK (disable users, admin API) |
| `backend/crops_recommendation.db` | Local SQLite (legacy / backup) |
| `backend/models/crop_model.joblib` | Trained ML model |
| `lib/firebase_options.dart` | Flutter Firebase config |
| `android/app/google-services.json` | Android Firebase config |

**Not in Git (generated on your PC):** `backend/.venv/`, `.dart_tool/`, `build/` — created by `setup-project.ps1`.

---

## Windows: Developer Mode (required)

If you see:

```text
Building with plugins requires symlink support.
Please enable Developer Mode in your system settings.
```

1. Run: `start ms-settings:developers`
2. Turn **Developer Mode** **On**
3. **Restart** the computer
4. Open a **new** PowerShell window, then:

```powershell
flutter pub get
flutter run -d chrome
```

The message `24 packages have newer versions` is safe to ignore.

---

## Setup (first time after clone)

### 1. Install dependencies

From the **project root**:

```powershell
.\scripts\setup-project.ps1
```

Creates `backend/.venv`, installs Python packages, runs `flutter pub get`, and verifies the ML model.

### 2. Environment (already committed)

`backend/.env` is ready. It points to:

```text
FIREBASE_CREDENTIALS_PATH=./edissaproject-firebase-adminsdk-fbsvc-eae48edf0e.json
FIREBASE_PROJECT_ID=edissaproject
```

Only if `.env` is missing on your machine:

```powershell
cd backend
copy .env.example .env
```

### 3. Firebase Console (project owner — usually already done)

Project: **edissaproject**

- [Email/Password sign-in](https://console.firebase.google.com/project/edissaproject/authentication/providers) — **enabled**
- **Cloud Firestore** — enabled
- **Authentication → Authorized domains** — include `localhost` (web + password reset)

Deploy rules (optional):

```powershell
firebase login
firebase deploy --only firestore:rules,firestore:indexes --project edissaproject
```

### 4. Seed admin user in Firebase

Creates/updates the admin account from `backend/.env`:

```powershell
cd backend
.\.venv\Scripts\python.exe scripts\seed_admin.py
```

Use the same email and password from `.env` on the login screen (role: **admin**).

---

## Run the application

Open **two** terminals.

### Terminal 1 — API (port 8000)

```powershell
# From project root
powershell -ExecutionPolicy Bypass -File .\scripts\start-api.ps1
```

Or:

```powershell
cd backend
.\.venv\Scripts\uvicorn.exe app.main:app --host 0.0.0.0 --port 8000 --reload
```

Check: open http://localhost:8000/docs in a browser.

### Terminal 2 — Flutter app

```powershell
# From project root
flutter run -d chrome
```

| Target | Command |
|--------|---------|
| Chrome (web) | `flutter run -d chrome` |
| Windows desktop | `flutter run -d windows` |
| Pick device | `flutter run` |

### API URL by device

| Platform | Base URL |
|----------|----------|
| Web (Chrome) | `http://localhost:8000` |
| Android emulator | `http://10.0.2.2:8000` |
| Phone on same Wi‑Fi | `http://<your-PC-LAN-IP>:8000` |

Defaults: `lib/core/constants.dart`.

---

## Features

| Area | What it does |
|------|----------------|
| Crop AI | Ranks crops from soil N-P-K, pH, moisture, season |
| Fertilizer | Urea, DAP, MOP, lime, organic matter from gaps |
| Soil health | Composite score from field readings |
| Weather | 7-day Open-Meteo forecast per Rwanda district |
| Feedback | Farmers rate outcomes; admin sees analytics |
| Roles | **Farmer** — register · **Admin** — seeded only |

---

## Using the app

### Farmer

1. **Register** — name, email, password, **district** (required for weather).
2. **Analyze** — soil type, season, nutrients, climate.
3. View crops, fertilizer plan, charts, forecast.
4. **History** — past runs and harvest feedback.
5. **Profile** — district, sign out, forgot password.

### Admin

1. Sign in with credentials from `backend/.env`.
2. **Dashboard** — health, stats, quick actions.
3. **Farmers** — list, disable, delete (needs Admin SDK JSON in repo).
4. **Data** — upload CSV, retrain model.
5. **Insights** — analytics, predictions, CSV export.
6. **Settings** — profile, password reset.

---

## Project structure

```
├── lib/                          # Flutter (screens, services, widgets)
├── backend/
│   ├── .env                      # Secrets & admin login (in repo)
│   ├── edissaproject-firebase-adminsdk-*.json
│   ├── app/                      # FastAPI routers & services
│   ├── models/                   # crop_model.joblib, active_dataset.csv
│   └── scripts/                  # seed_admin.py
├── ml/                           # train.py, sample_crop_data.csv
├── scripts/                      # setup-project.ps1, start-api.ps1
├── firestore.rules
└── android/app/google-services.json
```

---

## Train / refresh the ML model

```powershell
cd backend
.\.venv\Scripts\python.exe ..\ml\train.py
```

Or upload a CSV in the admin **Data** tab and train from the UI.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Symlink / Developer Mode | [Enable Developer Mode](#windows-developer-mode-required), restart PC |
| `flutter` not found | Install Flutter; run `flutter doctor` |
| Register / login fails | Check internet; confirm Email/Password in Firebase Console |
| Forgot password (web) | `localhost` in Firebase authorized domains |
| App shows API offline | Start uvicorn on port 8000; allow firewall |
| `ModuleNotFoundError` | Run `.\scripts\setup-project.ps1` from project root |
| Admin cannot delete users | Confirm `backend/.env` path matches the `*adminsdk*.json` file in `backend/` |
| After `git pull`, app breaks | Run `.\scripts\setup-project.ps1` again |

Short reference: [QUICKSTART.md](QUICKSTART.md)

---

## Updating your local copy

```powershell
cd AI-Powered-Multi-Factor-Crop-Recommendation-and-Fertilizer-System
git pull
.\scripts\setup-project.ps1
```

---

## Security note (team repo)

- Firebase Admin JSON and `backend/.env` are **intentionally committed** for collaborator setup.
- Keep the GitHub repository **private**. Do not fork publicly without rotating keys.
- Farmers register in-app; admins are created only via `seed_admin.py`.

---

## Production checklist

- [ ] Deploy `firestore.rules` and indexes
- [ ] Train on real Rwanda crop datasets
- [ ] HTTPS API URL in Flutter release build
- [ ] Restrict Firebase API keys in Console

---

## Links

| Resource | URL |
|----------|-----|
| GitHub | https://github.com/cracker38/AI-Powered-Multi-Factor-Crop-Recommendation-and-Fertilizer-System |
| Firebase Console | https://console.firebase.google.com/project/edissaproject |
| Firebase Auth | https://console.firebase.google.com/project/edissaproject/authentication/providers |
