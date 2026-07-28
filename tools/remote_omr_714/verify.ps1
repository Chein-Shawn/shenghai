$ErrorActionPreference = "Stop"

$serviceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvPython = "D:\VocalDiveOMR\venv\Scripts\python.exe"

if (-not (Test-Path $venvPython)) {
    throw "Missing worker virtual environment. Run install.ps1 first."
}

& nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
& $venvPython -c "import fitz, onnxruntime; import oemer; print('Python dependencies: ready')"
Invoke-RestMethod -Uri "http://127.0.0.1:8787/v1/health" | ConvertTo-Json
Write-Host "714 worker smoke check passed."
