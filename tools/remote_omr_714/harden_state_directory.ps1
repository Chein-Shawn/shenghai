param(
    [string]$StateRoot = "D:\VocalDiveOMR\state",
    [string]$ServiceRoot = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$ErrorActionPreference = "Stop"
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    throw "Run PowerShell as Administrator so the worker state directory can be protected."
}

New-Item -ItemType Directory -Force -Path $StateRoot | Out-Null
icacls $StateRoot /inheritance:r | Out-Null
icacls $StateRoot /grant:r "SYSTEM:(OI)(CI)F" "Administrators:(OI)(CI)F" | Out-Null
Write-Host "State directory ACL:"
icacls $StateRoot

$envFile = Join-Path $ServiceRoot ".env"
if (Test-Path $envFile) {
    icacls $envFile /inheritance:r | Out-Null
    icacls $envFile /grant:r "SYSTEM:F" "Administrators:F" | Out-Null
    Write-Host ".env ACL:"
    icacls $envFile
}
