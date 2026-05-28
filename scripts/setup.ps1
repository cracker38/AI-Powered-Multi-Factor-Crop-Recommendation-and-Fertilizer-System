# Full local setup for Crop Recommendation System
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

Write-Host "=== 1/5 Flutter dependencies ===" -ForegroundColor Cyan
flutter pub get 2>&1 | Out-Host

Write-Host "`n=== 2/5 Python virtual environment ===" -ForegroundColor Cyan
$venv = Join-Path $Root "backend\.venv"
$py = Join-Path $venv "Scripts\python.exe"
if (-not (Test-Path $py)) {
    python -m venv $venv
}
& $py -m pip install --upgrade pip -q
& $py -m pip install -r (Join-Path $Root "backend\requirements.txt")
if ($LASTEXITCODE -ne 0) {
    Write-Host "Retrying pip with extended timeout..." -ForegroundColor Yellow
    & $py -m pip install -r (Join-Path $Root "backend\requirements.txt") --default-timeout=120
}

Write-Host "`n=== 3/5 Train ML model ===" -ForegroundColor Cyan
& $py (Join-Path $Root "ml\train.py")

Write-Host "`n=== 4/5 Seed admin user (Firebase + database) ===" -ForegroundColor Cyan
Push-Location (Join-Path $Root "backend")
& $py (Join-Path $Root "backend\scripts\seed_admin.py")
Pop-Location

Write-Host "`n=== 5/5 Analyze Flutter ===" -ForegroundColor Cyan
flutter analyze 2>&1 | Out-Host

Write-Host "`nSetup complete." -ForegroundColor Green
Write-Host "Start API:  powershell -File scripts\start-api.ps1"
Write-Host "Run app:    flutter run"
Write-Host "Admin:      uwayiedissa@gmail.com  (password in backend\.env)"
