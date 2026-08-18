<#
.SYNOPSIS
    Discovers whether battery telemetry can be read.

.DESCRIPTION
    Intune custom compliance discovery script. The script reads Win32_Battery
    telemetry without generating reports or changing device configuration, then
    returns one compressed JSON object.

.NOTES
    Name:        Discover.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Custom Compliance
    Exit 0:      Discovery JSON was returned
    Exit 1:      Discovery failed

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

$ScriptPackageName = 'Check-Battery-Log-Snapshot'
$ScriptName = 'Discover'

$ManagedItemName = 'Battery Telemetry Snapshot'
$TreatNoBatteryAsCompliant = $true

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

$result = [ordered]@{
    BatteryLogSnapshotCompliant = $false
    ManagedItemName = $ManagedItemName
    BatteryCount = 0
    BatteryStatusCodes = ''
    EstimatedChargeRemainingPercent = ''
    TreatNoBatteryAsCompliant = $TreatNoBatteryAsCompliant
    ActualValue = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $batteries = @(Get-CimInstance -ClassName Win32_Battery -ErrorAction Stop)
    $result.BatteryCount = $batteries.Count
    $result.BatteryStatusCodes = [string](($batteries | ForEach-Object { [string]$_.BatteryStatus }) -join ',')
    $result.EstimatedChargeRemainingPercent = [string](($batteries | ForEach-Object { [string]$_.EstimatedChargeRemaining }) -join ',')

    if ($batteries.Count -eq 0) {
        $result.BatteryLogSnapshotCompliant = [bool]$TreatNoBatteryAsCompliant
        $result.ActualValue = if ($TreatNoBatteryAsCompliant) { 'NoBatteryAllowed' } else { 'NoBatteryDetected' }
    }
    else {
        $result.BatteryLogSnapshotCompliant = $true
        $result.ActualValue = 'BatteryTelemetryAvailable'
    }

    Write-Log -Message "Discovery completed. BatteryCount='$($result.BatteryCount)'; StatusCodes='$($result.BatteryStatusCodes)'; EstimatedCharge='$($result.EstimatedChargeRemainingPercent)'; Compliant='$($result.BatteryLogSnapshotCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.BatteryLogSnapshotCompliant = $false
    $result.ActualValue = 'Error'
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
