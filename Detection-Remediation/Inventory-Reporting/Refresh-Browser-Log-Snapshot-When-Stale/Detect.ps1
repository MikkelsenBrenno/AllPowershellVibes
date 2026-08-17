<#
.SYNOPSIS
    Detects Browser Log Snapshot state.

.DESCRIPTION
    Detects and remediates Browser Log Snapshot state for Intune-managed Windows devices.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Browser Log Snapshot is compliant
    Exit 1:      Browser Log Snapshot is noncompliant

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

$ScriptPackageName = 'Refresh-Browser-Log-Snapshot-When-Stale'
$ScriptName = 'Detect'

$SnapshotName = 'Browser Log Snapshot'
$SnapshotRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Snapshots\Inventory-Reporting'
$SnapshotFileName = 'browser-log-snapshot-snapshot.json'
$MaximumSnapshotAgeHours = 24

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"
$script:LogAvailable = $false

function Initialize-Log {
    try {
        if (-not (Test-Path -LiteralPath $LogRoot -PathType Container)) {
            New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
        }

        $script:LogAvailable = $true
    }
    catch {
        $script:LogAvailable = $false
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    if (-not $script:LogAvailable) {
        return
    }

    try {
        Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8
    }
    catch {
        $script:LogAvailable = $false
    }
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
    Write-Log -Message "Detection started. SnapshotName='$SnapshotName'; SnapshotFileName='$SnapshotFileName'; MaximumSnapshotAgeHours='$MaximumSnapshotAgeHours'."

    if ($MaximumSnapshotAgeHours -lt 1) {
        throw 'MaximumSnapshotAgeHours must be 1 or greater.'
    }

    $snapshotPath = Join-Path -Path $SnapshotRoot -ChildPath $SnapshotFileName
    if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) {
        Write-Output "Not compliant. Snapshot '$snapshotPath' is missing."
        exit 1
    }

    $snapshot = Get-Item -LiteralPath $snapshotPath -ErrorAction Stop
    $ageHours = [math]::Round(((Get-Date) - $snapshot.LastWriteTime).TotalHours, 2)

    if ($ageHours -le $MaximumSnapshotAgeHours) {
        Write-Output "Compliant. Snapshot '$SnapshotName' is current. AgeHours='$ageHours'."
        exit 0
    }

    Write-Output "Not compliant. Snapshot '$SnapshotName' is stale. AgeHours='$ageHours'; MaximumSnapshotAgeHours='$MaximumSnapshotAgeHours'."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. Snapshot '$SnapshotName' could not be validated."
    exit 1
}
