# AI-Powered Multi-Factor Crop Recommendation and Fertilizer System

**AgriSmart RW** — precision agriculture for Rwanda. Farmers get ML-based crop rankings, fertilizer plans, soil health scores, and district weather. Admins manage users, datasets, and model training.

| Stack | Technology |
|-------|------------|
| Mobile / Web | Flutter (Dart) |
| Auth & database | Firebase Auth, Cloud Firestore |
| API & ML | Python FastAPI, scikit-learn |
| Weather | Open-Meteo (no API key) |

---

## Features

| Area | Capability |
|------|------------|
| **Crop AI** | scikit-learn model ranks crops from field readings |
| **Fertilizer engine** | NPK gaps, urea/DAP/MOP, lime, organic matter |
| **Soil health** | Composite index from nutrients, pH, moisture |
| **Live weather** | Open-Meteo 7-day forecast per district |
| **Outcome feedback** | Farmers rate harvests; admin analytics |
| **Roles** | Farmer (self-register) · Admin (seeded only) |

---

## Prerequisites

Install these **before** cloning:

| Tool | Version | Check |
|------|---------|--------|
| [Flutter](https://docs.flutter.dev/get-started/install/windows) | Stable channel | `flutter doctor` |
| [Python](https://www.python.org/downloads/) | 3.10+ | `python --version` |
| [Git](https://git-scm.com/download/win) | Latest | `git --version` |
| Chrome (for web) | Latest | Used by `flutter run -d chrome` |

Optional: [Firebase CLI](https://firebase.google.com/docs/cli) for deploying Firestore rules.

---

## Clone the repository

```powershell
git clone https://github.com/cracker38/AI-Powered-Multi-Factor-Crop-Recommendation-and-Fertilizer-System.git
cd AI-Powered-Multi-Factor-Crop-Recommendation-and-Fertilizer-System
```

---

## Windows: enable Developer Mode (required)

If `flutter run` stops with:

```text
Building with plugins requires symlink support.
Please enable Developer Mode in your system settings.
```

1. Open **Settings → Privacy & security → For developers** (or **System → For developers**).
2. Turn **Developer Mode** **On**.
3. Restart your PC.
4. Open a **new** terminal and run `flutter run` again.

Quick link:

```powershell
start ms-settings:developers
```

> **Note:** The message `24 packages have newer versions` is only a warning — you can ignore it.

---

## Setup (first time after clone)

### Step 1 — Install dependencies and train the model

From the **project root**:

```powershell
.\scripts\setup-project.ps1
```

This script:

- Creates `backend/.venv` and installs Python packages
- Runs `flutter pub get`
- Ensures the ML model exists (`backend/models/crop_model.joblib`)

### Step 2 — Backend environment (not in Git)

Secrets are **not** pushed to GitHub. Create your local config:

```powershell
cd backend
copy .env.example .env
notepad .env
```

| Variable | What to set |
|----------|-------------|
| `FIREBASE_CREDENTIALS_PATH` | Path to service account JSON, e.g. `./firebase-service-account.json` |
| `FIREBASE_PROJECT_ID` | `edissaproject` (default in example) |
| `FIREBASE_WEB_API_KEY` | From Firebase Console → Project settings |
| `ADMIN_EMAIL` | Email for the system administrator |
| `ADMIN_PASSWORD` | Strong password (local only — never commit) |

Download the service account key:

1. [Firebase Console](https://console.firebase.google.com/project/edissaproject/settings/serviceaccounts/adminsdk) → **Service accounts** → **Generate new private key**
2. Save the file as `backend/firebase-service-account.json`

### Step 3 — Firebase Console (one-time)

Project: **edissaproject**

1. [Enable Email/Password sign-in](https://console.firebase.google.com/project/edissaproject/authentication/providers)
2. Enable **Cloud Firestore** (if not already)
3. Under **Authentication → Settings → Authorized domains**, ensure `localhost` is listed (needed for web and password reset)

Optional — deploy security rules from your machine:

```powershell
firebase login
firebase deploy --only firestore:rules,firestore:indexes --project edissaproject
```

### Step 4 — Seed the admin account

```powershell
cd backend
.\.venv\Scripts\python.exe scripts\seed_admin.py
```

Log in to the app with the **ADMIN_EMAIL** and **ADMIN_PASSWORD** from your `backend/.env`.

---

## Run the application

Use **two terminals**.

**Terminal 1 — API (port 8000)**

```powershell
# From project root
powershell -ExecutionPolicy Bypass -File .\scripts\start-api.ps1
```

Or manually:

```powershell
cd backend
.\.venv\Scripts\uvicorn.exe app.main:app --host 0.0.0.0 --port 8000 --reload
```

**Terminal 2 — Flutter**

```powershell
# From project root
flutter run -d chrome
```

Other devices:

```powershell
flutter devices          # list devices
flutter run -d windows   # desktop
flutter run              # pick from list
```

### API base URL

| Platform | URL |
|----------|-----|
| Web (Chrome) | `http://localhost:8000` |
| Android emulator | `http://10.0.2.2:8000` |
| Physical phone (same Wi‑Fi) | `http://<your-PC-LAN-IP>:8000` |

Defaults are in `lib/core/constants.dart`. Change them if your API runs on another host or port.

---

## Project structure

```
├── lib/                    # Flutter UI (farmer + admin)
├── backend/                # FastAPI, ML, Firestore access
│   ├── app/                # Routers, services
│   ├── models/             # crop_model.joblib, datasets
│   └── scripts/            # seed_admin.py, migrations
├── ml/                     # train.py, sample_crop_data.csv
├── firestore.rules         # Firestore security rules
├── scripts/                # setup-project.ps1, start-api.ps1
└── android/app/google-services.json   # Android Firebase config (in repo)
```

---

## Using the app

### Farmer

1. **Register** with name, email, password, and **district** (enables weather).
2. **Analyze** — enter soil type, season, N-P-K, pH, rainfall, etc.
3. View crop ranking, fertilizer plan, soil health, charts, and forecast.
4. **History** — past evaluations and harvest feedback.
5. **Profile** — update district, sign out, reset password.

### Admin

1. Sign in with the seeded admin account.
2. **Dashboard** — system health and quick stats.
3. **Farmers** — list, disable, or remove users (requires service account JSON).
4. **Data** — upload datasets, retrain the ML model.
5. **Insights** — analytics, predictions, exports.
6. **Settings** — account and password reset.

---

## Train or refresh the ML model

```powershell
cd backend
.\.venv\Scripts\python.exe ..\ml\train.py
```

Training uses `backend/models/active_dataset.csv`. Upload new CSVs from the admin **Data** tab or replace that file manually.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `symlink support` / Developer Mode | Enable Developer Mode (see above), restart PC |
| `flutter` not recognized | Add Flutter to PATH; run `flutter doctor` |
| Login or register fails | Enable Email/Password in Firebase; check internet |
| Forgot password email not received | Check spam; confirm `localhost` in authorized domains (web) |
| API errors / “offline” in app | Start uvicorn on port 8000; check firewall |
| Admin panel cannot disable users | Add `backend/firebase-service-account.json` and restart API |
| `ModuleNotFoundError` (Python) | Run `.\scripts\setup-project.ps1` or activate `backend\.venv` |

More detail: [QUICKSTART.md](QUICKSTART.md)

---

## Security

- **Never commit** `backend/.env`, `firebase-service-account.json`, or `*adminsdk*.json` (listed in `.gitignore`).
- Use **placeholder values** in `.env.example`; put real secrets only in `.env` locally.
- Admins are created only via `backend/scripts/seed_admin.py`, not public registration.
- Deploy `firestore.rules` before production use.

---

## Production checklist

- [ ] Deploy Firestore rules and indexes
- [ ] Train model on a real Rwanda agricultural dataset
- [ ] Rotate Firebase keys if they were ever exposed
- [ ] Set a strong `ADMIN_PASSWORD` in `.env` only
- [ ] Point Flutter API URL to HTTPS in release builds
- [ ] Restrict Firebase API keys by app ID / domain in Console

---

## License

Add a `LICENSE` file if you publish this repository publicly (e.g. MIT).

---

## Links

- **Repository:** https://github.com/cracker38/AI-Powered-Multi-Factor-Crop-Recommendation-and-Fertilizer-System
- **Firebase project:** https://console.firebase.google.com/project/edissaproject
