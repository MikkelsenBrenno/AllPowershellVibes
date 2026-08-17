<#
.SYNOPSIS
    Detects whether the last Group Policy refresh is older than expected.

.DESCRIPTION
    Intune Remediations detection script. The script reads the machine Group
    Policy refresh timestamp from the registry and triggers remediation when
    the timestamp is missing or older than the configured threshold.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Group Policy refresh is within threshold
    Exit 1:      Group Policy refresh is stale or could not be validated

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

$ScriptPackageName = 'Refresh-Group-Policy-When-Stale'
$ScriptName = 'Detect'

$MaximumRefreshAgeDays = 7
$MachineGroupPolicyStatePath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\State\Machine\Extension-List\{00000000-0000-0000-0000-000000000000}'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-GroupPolicyRefreshDate {
    $state = Get-ItemProperty -LiteralPath $MachineGroupPolicyStatePath -ErrorAction Stop
    $high = [int64]$state.startTimeHi
    $low = [int64]$state.startTimeLo
    $fileTime = ($high -shl 32) -bor $low
    return [datetime]::FromFileTime($fileTime)
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $lastRefresh = Get-GroupPolicyRefreshDate
    $ageDays = [int](New-TimeSpan -Start $lastRefresh -End (Get-Date)).TotalDays

    if ($ageDays -le $MaximumRefreshAgeDays) {
        $message = "Compliant. Last Group Policy refresh was '$ageDays' days ago at '$($lastRefresh.ToString('s'))'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Last Group Policy refresh was '$ageDays' days ago; Threshold='$MaximumRefreshAgeDays'."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Group Policy refresh timestamp could not be validated.'
    exit 1
}
