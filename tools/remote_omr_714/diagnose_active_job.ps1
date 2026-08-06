param(
    [string]$JobId
)

$ErrorActionPreference = "Stop"

$serviceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$venvPython = "D:\VocalDiveOMR\venv\Scripts\python.exe"
$jobsDatabase = "D:\VocalDiveOMR\state\jobs.sqlite3"

if (-not (Test-Path $venvPython)) {
    throw "Missing worker Python at $venvPython."
}
if (-not (Test-Path $jobsDatabase)) {
    throw "Missing worker queue database at $jobsDatabase."
}

if ([string]::IsNullOrWhiteSpace($JobId)) {
    $JobId = & $venvPython -c @"
import sqlite3
connection = sqlite3.connect(r'$jobsDatabase')
row = connection.execute("SELECT job_id FROM jobs WHERE state IN ('rasterizing', 'recognizing', 'assembling') ORDER BY updated_at DESC LIMIT 1").fetchone()
print(row[0] if row else '')
"@
}

if ([string]::IsNullOrWhiteSpace($JobId)) {
    Write-Host "No active OMR job was found. Supply -JobId to inspect a completed or failed job."
    exit 0
}

Write-Host "=== Job status ==="
& $venvPython -c @"
import json, sqlite3, sys
connection = sqlite3.connect(r'$jobsDatabase')
connection.row_factory = sqlite3.Row
row = connection.execute("SELECT job_id, state, source_name, total_pages, completed_pages, detail, error_code, created_at, started_at, finished_at, telemetry_json, runtime_json, job_root FROM jobs WHERE job_id = ?", (sys.argv[1],)).fetchone()
if not row:
    raise SystemExit('Unknown job id')
payload = dict(row)
for key in ('telemetry_json', 'runtime_json'):
    payload[key[:-5]] = json.loads(payload.pop(key)) if payload.get(key) else None
print(json.dumps(payload, indent=2))
"@ $JobId

Write-Host "=== GPU ==="
& nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits

Write-Host "=== Active recognition processes ==="
Get-Process oemer, python -ErrorAction SilentlyContinue |
    Select-Object ProcessName, Id, CPU, WorkingSet64 |
    Format-Table -AutoSize

$jobRoot = & $venvPython -c @"
import sqlite3, sys
connection = sqlite3.connect(r'$jobsDatabase')
row = connection.execute('SELECT job_root FROM jobs WHERE job_id = ?', (sys.argv[1],)).fetchone()
print(row[0] if row else '')
"@ $JobId

if ($jobRoot -and (Test-Path $jobRoot)) {
    Write-Host "=== Job artifacts ==="
    Get-ChildItem $jobRoot -Recurse -File |
        Select-Object FullName, Length, LastWriteTime |
        Format-Table -AutoSize
    $events = Join-Path $jobRoot "diagnostics\events.jsonl"
    if (Test-Path $events) {
        Write-Host "=== Recent normalized events ==="
        Get-Content $events -Tail 20
    }
} else {
    Write-Warning "The date folder for this job is no longer available. Queue metadata above remains available."
}

Write-Host "=== Recent worker log ==="
$workerLog = "D:\VocalDiveOMR\state\logs\worker.log"
if (Test-Path $workerLog) {
    Get-Content $workerLog -Tail 80
} else {
    Write-Warning "No persistent worker log exists yet. Restart the worker after installing this diagnostic update."
}
