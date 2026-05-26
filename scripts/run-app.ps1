# Run Crop Recommendation app (Chrome by default; Windows if Developer Mode enabled)
$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

# Ensure API is up
try {
    $h = Invoke-WebRequest -Uri "http://127.0.0.1:8000/health" -UseBasicParsing -TimeoutSec 2
    Write-Host "API: OK" -ForegroundColor Green
} catch {
    Write-Host "Starting API..." -ForegroundColor Yellow
    Start-Process -FilePath "powershell" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File","$Root\scripts\start-api.ps1" -WindowStyle Minimized
    Start-Sleep -Seconds 4
}

Set-Location $Root
$device = $args[0]
if (-not $device) { $device = "chrome" }

Write-Host "Launching Flutter on: $device" -ForegroundColor Cyan
Write-Host "API URL on login: http://127.0.0.1:8000 (Chrome/Windows) or http://10.0.2.2:8000 (Android emulator)" -ForegroundColor Gray
flutter run -d $device
