$ErrorActionPreference = "Stop"
$serviceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvPython = "D:\VocalDiveOMR\venv\Scripts\python.exe"

Get-Content "$serviceRoot\.env" | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $name, $value = $_ -split '=', 2
    [Environment]::SetEnvironmentVariable($name.Trim(), $value.Trim(), 'Process')
}

& $venvPython -m uvicorn server:app --app-dir $serviceRoot --host $env:VOCALDIVE_OMR_HOST --port $env:VOCALDIVE_OMR_PORT
