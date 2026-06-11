# Run from backend/ — starts FastAPI on http://0.0.0.0:8000
$Backend = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$venv = Join-Path $Backend ".venv"
if (-not (Test-Path $venv)) {
    Write-Host "Virtual env missing. From project root run: powershell -ExecutionPolicy Bypass -File scripts\setup.ps1" -ForegroundColor Red
    exit 1
}
Set-Location $Backend
$env:GRPC_DNS_RESOLVER = "native"
$uvicorn = Join-Path $venv "Scripts\uvicorn.exe"
Write-Host "Starting API at http://127.0.0.1:8000 (docs: /docs)" -ForegroundColor Green
& $uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
