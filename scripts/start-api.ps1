$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$venv = Join-Path $Root "backend\.venv"
if (-not (Test-Path $venv)) {
    Write-Host "Run scripts\setup.ps1 first." -ForegroundColor Red
    exit 1
}
Set-Location (Join-Path $Root "backend")
& "..\$venv\Scripts\uvicorn.exe" app.main:app --reload --host 0.0.0.0 --port 8000
