$ErrorActionPreference = "Stop"

$serviceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvPython = "D:\VocalDiveOMR\venv\Scripts\python.exe"
$envFile = "$serviceRoot\.env"

if (-not (Test-Path $venvPython)) {
    throw "Missing worker virtual environment. Run install.ps1 first."
}
if (-not (Test-Path $envFile)) {
    throw "Missing .env. Copy .env.example and add the Resend sending key."
}
if (-not (Select-String -Path $envFile -Pattern '^VOCALDIVE_OMR_RESEND_API_KEY=.+$' -Quiet)) {
    throw "Resend email sign-in is not configured. Add the restricted sending key to .env before verifying this beta."
}

& nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
& $venvPython -c "import fitz, onnxruntime, psutil; import oemer; print('Python dependencies: ready')"
& $venvPython -c "import server; print(f'oemer CLI: {server.available_oemer_executable()}')"
& $venvPython -c "import server, subprocess; subprocess.run([str(server.available_oemer_executable()), '--help'], check=True, capture_output=True, text=True); print('oemer CLI: ready')"
$health = Invoke-RestMethod -Uri "http://127.0.0.1:8787/v1/health"
$health | ConvertTo-Json
if (-not $health.email_sign_in_ready) {
    throw "The worker did not load the Resend sending key. Restart the worker after correcting .env."
}
if (-not $health.engine_ready) {
    throw "The oemer CLI is unavailable. Repair the worker environment before accepting score uploads."
}
if (-not (Test-Path "D:\VocalDiveOMR\state\logs")) {
    Write-Warning "Worker logs will be created after the next successful worker startup."
}
Write-Host "714 worker smoke check passed."
