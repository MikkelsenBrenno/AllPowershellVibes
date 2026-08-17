<#
.SYNOPSIS
    Detects whether a local troubleshooting snapshot is current.

.DESCRIPTION
    Intune Remediations detection script. The script checks for a local JSON
    troubleshooting snapshot and exits 0 when the file exists and is fresh.
    It exits 1 when remediation should refresh the snapshot.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Troubleshooting snapshot is current
    Exit 1:      Troubleshooting snapshot is missing or stale

.CUSTOMIZATION
    Update values in the CONFIGURATION section before deployment.
#>

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

# =========================
# CONFIGURATION
# =========================

# CUSTOMIZE HERE.
# Keep every value an admin is expected to change in this section.
# Common examples: file paths, registry paths, service names, URLs,
# tenant-specific labels, expected values, and validation timing.

$ScriptPackageName = 'Refresh-Device-Troubleshooting-Snapshot'
$ScriptName = 'Detect'

$SnapshotRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$SnapshotFileName = 'DeviceTroubleshootingSnapshot.json'
$MaximumSnapshotAgeHours = 24

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if ($MaximumSnapshotAgeHours -lt 1) {
        throw 'MaximumSnapshotAgeHours must be 1 or greater.'
    }

    $snapshotPath = Join-Path -Path $SnapshotRoot -ChildPath $SnapshotFileName

    if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) {
        Write-Output "Not compliant. Snapshot '$snapshotPath' is missing."
        exit 1
    }

    $snapshotItem = Get-Item -LiteralPath $snapshotPath -ErrorAction Stop
    $age = New-TimeSpan -Start $snapshotItem.LastWriteTime -End (Get-Date)
    $ageHours = [math]::Round($age.TotalHours, 2)
    Write-Log -Message "SnapshotPath='$snapshotPath'; LastWriteTime='$($snapshotItem.LastWriteTime)'; AgeHours='$ageHours'."

    if ($age.TotalHours -le $MaximumSnapshotAgeHours) {
        Write-Output "Compliant. Troubleshooting snapshot is $ageHours hours old."
        exit 0
    }

    Write-Output "Not compliant. Troubleshooting snapshot is $ageHours hours old."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Troubleshooting snapshot could not be validated.'
    exit 1
}
