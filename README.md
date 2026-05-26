# AgriSmart RW

**AI-Powered Multi-Factor Crop Recommendation and Fertilizer System** for Rwanda.

Helps farmers choose suitable crops and fertilizers using machine learning, soil analysis, seasonal weather (including live Open-Meteo forecasts), and precision agriculture guidance.

## Features

| Area | Capability |
|------|------------|
| **Crop AI** | scikit-learn model ranks crops from field readings |
| **Fertilizer engine** | NPK gaps, urea/DAP/MOP, lime, organic matter |
| **Soil health** | Composite index from nutrients, pH, moisture |
| **Live weather** | Open-Meteo 7-day forecast per district |
| **Outcome feedback** | Farmers rate harvests; admin analytics |
| **Roles** | Farmer (self-register) · Admin (seeded only) |
| **Data** | Firebase Auth + Cloud Firestore |

## Quick start (Windows / XAMPP)

```powershell
# From project root — installs deps, trains ML model, runs flutter pub get
.\scripts\setup-project.ps1

cd backend
copy .env.example .env
# Edit .env: FIREBASE_CREDENTIALS_PATH, ADMIN_EMAIL, ADMIN_PASSWORD

.\.venv\Scripts\python.exe scripts\seed_admin.py
.\.venv\Scripts\uvicorn.exe app.main:app --host 0.0.0.0 --port 8000 --reload

# New terminal
flutter run -d chrome
```

## Project structure

```
crops_recommendation/
├── lib/                    # Flutter app (AgriSmart RW)
├── backend/                # FastAPI + Firestore
│   └── models/             # crop_model.joblib, datasets
├── ml/                     # train.py, sample_crop_data.csv
├── firestore.rules         # Production security rules
└── scripts/                # setup-project.ps1, start-api.ps1
```

## Firebase setup

1. Enable **Email/Password** authentication.
2. Enable **Cloud Firestore**.
3. Deploy rules: `firebase deploy --only firestore:rules,firestore:indexes`
4. Service account JSON → path in `backend/.env` as `FIREBASE_CREDENTIALS_PATH`.
5. `android/app/google-services.json` for Android builds.

## API URL (Flutter)

Configured in `lib/core/constants.dart`:

- Web: `http://localhost:8000`
- Android emulator: `http://10.0.2.2:8000`

## Farmer workflow

1. Register with **district** (enables live weather).
2. **Analyze** → soil type, season, N-P-K, climate readings.
3. Receive crop ranking, fertilizer plan, soil health, charts, weather.
4. **Rate harvest outcome** from results or history.
5. **Profile** → update district, password reset.

## Admin workflow

Operations dashboard → farmers → datasets & ML training → insights (analytics, audit, alerts) → settings.

## Train / refresh ML model

```powershell
python ml/train.py
```

Requires `backend/models/active_dataset.csv` (copied from `ml/data/sample_crop_data.csv` on first setup).

## Security

- Production Firestore rules in `firestore.rules` (role-based).
- Admin cannot self-register; use `backend/scripts/seed_admin.py`.
- API enforces roles via Firebase ID tokens.

## Production checklist

- [ ] Deploy Firestore rules and indexes
- [ ] Train model on real Rwanda agricultural dataset
- [ ] Set strong `ADMIN_PASSWORD` in `.env` only (never commit `.env`)
- [ ] Configure HTTPS API URL in Flutter for release builds
- [ ] Replace default web icons with branded assets (optional)
