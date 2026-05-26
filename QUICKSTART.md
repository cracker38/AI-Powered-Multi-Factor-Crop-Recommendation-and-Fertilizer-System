# Quick start (Windows)

## Done automatically

- Python venv + packages in `backend/.venv`
- ML model trained (`backend/models/crop_model.joblib`)
- Flutter dependencies + analyzer clean

## Firestore collections (Firebase Console)

| Collection | Document ID | Contents |
|------------|-------------|----------|
| `users` | Firebase `uid` | email, role, display_name, disabled |
| `predictions` | auto-id | crop results per farmer |
| `training_datasets` | auto-id | CSV metadata (admin) |
| `system` | `model` | ML metadata after training |

## One manual step (Firebase)

Enable **Email/Password** authentication:

https://console.firebase.google.com/project/edissaproject/authentication/providers

Then seed the admin:

```powershell
cd c:\xampp\htdocs\crops_recommendation\backend
..\.venv\Scripts\python.exe scripts\seed_admin.py
```

Admin login: `it.elias38@gmail.com` / password from `backend/.env`

## Run

**Terminal 1 — API**

```powershell
powershell -ExecutionPolicy Bypass -File c:\xampp\htdocs\crops_recommendation\scripts\start-api.ps1
```

**Terminal 2 — App**

```powershell
cd c:\xampp\htdocs\crops_recommendation
flutter run
```

Set API URL on login screen:

| Device | URL |
|--------|-----|
| Android emulator | `http://10.0.2.2:8000` |
| Physical phone | `http://<your-PC-LAN-IP>:8000` |

## Optional

- Enable **Windows Developer Mode** (Settings → For developers) if Flutter warns about symlinks.
- Add `backend/firebase-service-account.json` to enable disabling users from the admin panel.
