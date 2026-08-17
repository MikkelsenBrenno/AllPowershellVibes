<#
.SYNOPSIS
    Detects whether the Teams Cache Snapshot snapshot is current.

.DESCRIPTION
    Intune Remediations detection script. The script checks whether the
    configured troubleshooting snapshot exists and is newer than the allowed
    age. It exits 1 when remediation should refresh the snapshot.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Snapshot is current
    Exit 1:      Snapshot is missing, stale, or unavailable

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

# Keep these names aligned with the folder and script file.
# Logs are written to Logs\<ScriptPackageName>\<ScriptName>.log.
$ScriptPackageName = 'Refresh-Teams-Cache-Snapshot-When-Stale'
$ScriptName = 'Detect'

$SnapshotRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\RemediationSnapshots'
$SnapshotFileName = 'TeamsCacheSnapshot.json'
$MaximumSnapshotAgeHours = 24

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. SnapshotFileName='$SnapshotFileName'; MaximumSnapshotAgeHours='$MaximumSnapshotAgeHours'."

    if ($MaximumSnapshotAgeHours -lt 1) {
        throw 'MaximumSnapshotAgeHours must be 1 or greater.'
    }

    $snapshotPath = Join-Path -Path $SnapshotRoot -ChildPath $SnapshotFileName
    if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) {
        $message = "Not compliant. Snapshot '$snapshotPath' is missing."
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message
        exit 1
    }

    $snapshot = Get-Item -LiteralPath $snapshotPath -ErrorAction Stop
    $ageHours = [math]::Round(((Get-Date) - $snapshot.LastWriteTime).TotalHours, 2)
    Write-Log -Message "Snapshot '$snapshotPath' age is '$ageHours' hours."

    if ($ageHours -le $MaximumSnapshotAgeHours) {
        $message = "Compliant. Snapshot is current. AgeHours='$ageHours'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Snapshot is stale. AgeHours='$ageHours'; MaximumSnapshotAgeHours='$MaximumSnapshotAgeHours'."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Not compliant. Snapshot state could not be validated.'
    exit 1
}

