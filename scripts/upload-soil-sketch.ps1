# Compile, upload, and monitor SOIL7In_one_9b.ino (ESP8266 / NodeMCU) - no Python
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$SketchDir = Join-Path $Root "SOIL7In_one_9b"
$SketchIno = Join-Path $Root "SOIL7In_one_9b.ino"
$IdxUrl = "file:///C:/Users/iteli/AppData/Local/Arduino15/package_esp8266com_index.json"
$Fqbn = "esp8266:esp8266:nodemcuv2"

$cli = Join-Path $env:TEMP "arduino-cli\arduino-cli.exe"
if (-not (Test-Path $cli)) {
    Write-Host "Downloading arduino-cli..." -ForegroundColor Yellow
    $dest = Join-Path $env:TEMP "arduino-cli"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $zip = Join-Path $dest "arduino-cli.zip"
    Invoke-WebRequest -Uri "https://downloads.arduino.cc/arduino-cli/arduino-cli_latest_Windows_64bit.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $dest -Force
}

if (-not (Test-Path (Join-Path $env:LOCALAPPDATA "Arduino15\package_esp8266com_index.json"))) {
    Write-Host "Downloading ESP8266 board index from GitHub..." -ForegroundColor Yellow
    curl.exe -L --max-time 120 -o "$env:LOCALAPPDATA\Arduino15\package_esp8266com_index.json" `
        "https://github.com/esp8266/Arduino/releases/download/3.1.2/package_esp8266com_index.json"
}

$core = & $cli core list --additional-urls $IdxUrl 2>&1 | Select-String "esp8266:esp8266"
if (-not $core) {
    Write-Host "Installing ESP8266 core (first time only)..." -ForegroundColor Yellow
    & $cli core install "esp8266:esp8266@3.1.2" --additional-urls $IdxUrl
}

New-Item -ItemType Directory -Force -Path $SketchDir | Out-Null
Copy-Item $SketchIno (Join-Path $SketchDir "SOIL7In_one_9b.ino") -Force

Write-Host "Compiling..." -ForegroundColor Cyan
& $cli compile --fqbn $Fqbn --additional-urls $IdxUrl $SketchDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$ports = [System.IO.Ports.SerialPort]::getportnames()
if ($ports.Count -eq 0) {
    Write-Host "Compile OK. No COM port found - plug in NodeMCU via USB, then run:" -ForegroundColor Yellow
    Write-Host "  powershell -File scripts\upload-soil-sketch.ps1 -Upload" -ForegroundColor White
    exit 0
}

$port = $ports[0]
Write-Host "Uploading to $port ..." -ForegroundColor Cyan
& $cli upload --fqbn $Fqbn --port $port --additional-urls $IdxUrl $SketchDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Opening Serial Monitor (115200) - Ctrl+C to stop" -ForegroundColor Green
& $cli monitor --port $port --config 115200
