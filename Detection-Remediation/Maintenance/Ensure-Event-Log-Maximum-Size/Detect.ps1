<#
.SYNOPSIS
    Detects whether configured Windows event logs meet a minimum maximum size.

.DESCRIPTION
    Intune Remediations detection script. The script checks event log maximum
    sizes using Get-WinEvent and reports noncompliance when any configured log
    is below the expected size.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Event logs meet the configured minimum size
    Exit 1:      One or more event logs are too small or unavailable

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

$ScriptPackageName = 'Ensure-Event-Log-Maximum-Size'
$ScriptName = 'Detect'

$TargetLogs = @('Application', 'System')
$MinimumMaximumSizeBytes = 67108864

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

    $tooSmall = @()

    foreach ($logName in $TargetLogs) {
        $log = Get-WinEvent -ListLog $logName -ErrorAction Stop
        Write-Log -Message "Event log '$logName' MaximumSizeInBytes='$($log.MaximumSizeInBytes)'."

        if ([int64]$log.MaximumSizeInBytes -lt [int64]$MinimumMaximumSizeBytes) {
            $tooSmall += "$logName=$($log.MaximumSizeInBytes)"
        }
    }

    if ($tooSmall.Count -eq 0) {
        $message = 'Compliant. Event log maximum sizes meet the configured minimum.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Event logs below minimum: $($tooSmall -join ', ')."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Event log maximum sizes could not be validated.'
    exit 1
}
