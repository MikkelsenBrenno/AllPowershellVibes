<#
.SYNOPSIS
    Detects stale Windows Update scan state.

.DESCRIPTION
    Intune Remediations detection script. The script checks Windows Update
    AutoUpdate scan results and exits 1 when the last successful scan is stale
    or unavailable, allowing remediation to refresh local update components.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Windows Update scan is recent
    Exit 1:      Windows Update scan is stale or unavailable

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

$ScriptPackageName = 'Reset-Windows-Update-Components-Safely'
$ScriptName = 'Detect'

$MaximumLastScanAgeDays = 7
$TreatUnavailableScanHistoryAsNonCompliant = $true

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

    $autoUpdate = New-Object -ComObject 'Microsoft.Update.AutoUpdate'
    $results = $autoUpdate.Results
    $lastSearchSuccessDate = $results.LastSearchSuccessDate

    if ($null -eq $lastSearchSuccessDate -or $lastSearchSuccessDate.Year -lt 2000) {
        Write-Output 'Not compliant. Windows Update scan history is unavailable.'
        if ($TreatUnavailableScanHistoryAsNonCompliant) { exit 1 } else { exit 0 }
    }

    $age = New-TimeSpan -Start $lastSearchSuccessDate -End (Get-Date)
    $ageDays = [math]::Round($age.TotalDays, 2)
    Write-Log -Message "LastSearchSuccessDate='$lastSearchSuccessDate'; AgeDays='$ageDays'."

    if ($age.TotalDays -le $MaximumLastScanAgeDays) {
        Write-Output "Compliant. Windows Update last successful scan is $ageDays days old."
        exit 0
    }

    Write-Output "Not compliant. Windows Update last successful scan is $ageDays days old."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Windows Update scan state could not be validated.'
    exit 1
}
