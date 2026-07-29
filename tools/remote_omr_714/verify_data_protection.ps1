param(
    [string]$DataDrive = "D:",
    [string]$StateRoot = "D:\VocalDiveOMR\state",
    [string]$ServiceRoot = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

$ErrorActionPreference = "Stop"
Get-BitLockerVolume -MountPoint $DataDrive |
    Select-Object MountPoint, VolumeStatus, ProtectionStatus, EncryptionPercentage |
    Format-List
Write-Host "State directory ACL:"
icacls $StateRoot
Write-Host ".env ACL:"
icacls (Join-Path $ServiceRoot ".env")
