<#
.SYNOPSIS
    Sets configured Windows event logs to a minimum maximum size.

.DESCRIPTION
    Intune Remediations remediation script. The script uses wevtutil to set
    the maximum size for configured event logs when they are below the target.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Event log size remediation completed
    Exit 1:      Event log size remediation failed

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
$ScriptName = 'Remediate'

$TargetLogs = @('Application', 'System')
$MinimumMaximumSizeBytes = 67108864
$WevtutilPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\wevtutil.exe'

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

    if (-not (Test-Path -LiteralPath $WevtutilPath -PathType Leaf)) {
        throw "wevtutil.exe was not found at '$WevtutilPath'."
    }

    foreach ($logName in $TargetLogs) {
        $log = Get-WinEvent -ListLog $logName -ErrorAction Stop
        if ([int64]$log.MaximumSizeInBytes -lt [int64]$MinimumMaximumSizeBytes) {
            Write-Log -Message "Updating event log '$logName' from '$($log.MaximumSizeInBytes)' to '$MinimumMaximumSizeBytes'."
            & $WevtutilPath sl $logName "/ms:$MinimumMaximumSizeBytes"

            if ($LASTEXITCODE -ne 0) {
                throw "wevtutil failed for event log '$logName' with exit code '$LASTEXITCODE'."
            }
        }
    }

    Write-Output 'Remediation completed. Event log maximum sizes are configured.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Event log maximum sizes were not configured.'
    exit 1
}
