$ErrorActionPreference = "Stop"

$serviceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$taskName = "VocalDive CRM Backup"
$taskCommand = "powershell.exe -ExecutionPolicy Bypass -File `"$serviceRoot\backup_google_drive.ps1`""

if (-not (Get-Command rclone -ErrorAction SilentlyContinue)) {
    throw "Install rclone and configure the Google Drive remote before creating the backup task."
}

schtasks /Create /TN $taskName /SC DAILY /ST 03:15 /RU SYSTEM /RL HIGHEST /TR $taskCommand /F
Write-Host "Installed $taskName. Run it once with: schtasks /Run /TN `"$taskName`""
