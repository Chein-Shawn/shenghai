param(
    [Parameter(Mandatory = $true)]
    [string]$Date,
    [string]$Destination = "D:\VocalDiveOMR\state\restore-test\crm.sqlite3"
)

$ErrorActionPreference = "Stop"
$serviceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $serviceRoot ".env"
$venvPython = "D:\VocalDiveOMR\venv\Scripts\python.exe"

Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $name, $value = $_ -split '=', 2
    [Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim(), 'Process')
}

$remote = "$($env:VOCALDIVE_OMR_GOOGLE_DRIVE_REMOTE.TrimEnd('/'))/$Date/crm.sqlite3"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
& rclone --config $env:VOCALDIVE_OMR_RCLONE_CONFIG copyto $remote $Destination --checksum
& $venvPython -c "import sqlite3, sys; db=sqlite3.connect(sys.argv[1]); print(db.execute('PRAGMA integrity_check').fetchone()[0]); print(db.execute(\"SELECT value FROM schema_metadata WHERE key = 'schema_version'\").fetchone()[0]); db.close()" $Destination
Write-Host "Restored only into test path: $Destination"
