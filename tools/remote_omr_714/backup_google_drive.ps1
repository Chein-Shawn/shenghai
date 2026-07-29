$ErrorActionPreference = "Stop"

$serviceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $serviceRoot ".env"
$venvPython = "D:\VocalDiveOMR\venv\Scripts\python.exe"

if (-not (Test-Path $envFile)) { throw "Missing $envFile" }
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $name, $value = $_ -split '=', 2
    [Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim(), 'Process')
}

if (-not $env:VOCALDIVE_OMR_GOOGLE_DRIVE_REMOTE) {
    throw "Set VOCALDIVE_OMR_GOOGLE_DRIVE_REMOTE in .env before enabling backups."
}
if (-not (Test-Path $env:VOCALDIVE_OMR_RCLONE_CONFIG)) {
    throw "Missing rclone config: $env:VOCALDIVE_OMR_RCLONE_CONFIG"
}
if (-not (Get-Command rclone -ErrorAction SilentlyContinue)) {
    throw "Install rclone and make it available on PATH before enabling backups."
}

$stateRoot = $env:VOCALDIVE_OMR_STATE_ROOT
$date = Get-Date -Format "yyyy-MM-dd"
$backupRoot = Join-Path $stateRoot "backups\$date"
$snapshot = Join-Path $backupRoot "crm.sqlite3"
$manifest = Join-Path $backupRoot "crm-audit.json"

& $venvPython (Join-Path $serviceRoot "backup_crm.py") `
    --database $env:VOCALDIVE_OMR_CRM_DATABASE `
    --output $snapshot `
    --audit-manifest $manifest

$remote = "$($env:VOCALDIVE_OMR_GOOGLE_DRIVE_REMOTE.TrimEnd('/'))/$date"
& rclone --config $env:VOCALDIVE_OMR_RCLONE_CONFIG copy $backupRoot $remote --checksum
Write-Host "CRM backup copied to $remote"
