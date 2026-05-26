# One-time / fresh clone setup for AgriSmart RW
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Write-Host "=== AgriSmart RW setup ===" -ForegroundColor Green

# Backend venv
$venv = Join-Path $Root "backend\.venv"
if (-not (Test-Path $venv)) {
    Write-Host "Creating Python venv..."
    python -m venv $venv
}
& "$venv\Scripts\pip.exe" install -r "$Root\backend\requirements.txt" -q

# ML dataset + model
$active = Join-Path $Root "backend\models\active_dataset.csv"
$sample = Join-Path $Root "ml\data\sample_crop_data.csv"
if (-not (Test-Path $active)) {
    Copy-Item $sample $active
    Write-Host "Copied sample dataset to backend\models\active_dataset.csv"
}
python "$Root\ml\train.py"
Write-Host "ML model trained -> backend\models\crop_model.joblib"

# Flutter
Push-Location $Root
flutter pub get
Pop-Location

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Copy backend\.env.example to backend\.env and set credentials"
Write-Host "  2. python backend\scripts\seed_admin.py"
Write-Host "  3. Start API: backend\.venv\Scripts\uvicorn.exe app.main:app --host 0.0.0.0 --port 8000 --reload"
Write-Host "  4. flutter run -d chrome"
