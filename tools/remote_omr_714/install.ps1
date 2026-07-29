$ErrorActionPreference = "Stop"

$serviceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$stateRoot = "D:\VocalDiveOMR\state"
$venvRoot = "D:\VocalDiveOMR\venv"

New-Item -ItemType Directory -Force -Path $stateRoot | Out-Null
if (-not (Test-Path "$serviceRoot\.env")) {
    Copy-Item "$serviceRoot\.env.example" "$serviceRoot\.env"
}
if (-not (Test-Path "$stateRoot\tokens.json")) {
    Copy-Item "$serviceRoot\tokens.example.json" "$stateRoot\tokens.json"
    Write-Warning "Replace the sample token in $stateRoot\tokens.json before using operator mode or storage dashboard endpoints."
}

py -3.11 -m venv $venvRoot
& "$venvRoot\Scripts\python.exe" -m pip install --upgrade pip
& "$venvRoot\Scripts\python.exe" -m pip install -r "$serviceRoot\requirements.txt"

$taskName = "VocalDive OMR Worker"
$taskCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$serviceRoot\run.ps1`""
schtasks /Create /TN $taskName /SC ONSTART /RU SYSTEM /RL HIGHEST /TR $taskCommand /F

Write-Host "Installed $taskName. Start it now with: schtasks /Run /TN `"$taskName`""
Write-Host "Before that, add the restricted Resend sending key to $serviceRoot\.env and replace the operator token in $stateRoot\tokens.json."
