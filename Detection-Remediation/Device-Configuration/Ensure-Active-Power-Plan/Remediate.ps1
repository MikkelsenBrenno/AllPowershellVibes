<#
.SYNOPSIS
    Sets the active Windows power plan.

.DESCRIPTION
    Intune Remediations remediation script. The script can set a configured
    Windows power plan GUID as active and validate the final state. It starts
    in report-only mode so administrators can confirm the target plan first.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Power plan configured
    Exit 1:      Remediation failed or report-only mode is enabled

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

$ScriptPackageName = 'Ensure-Active-Power-Plan'
$ScriptName = 'Remediate'

$TargetPowerPlanGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'
$ApplyPowerPlan = $false
$ExitZeroInReportingOnlyMode = $false

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-ActivePowerPlanGuid {
    $output = (& powercfg.exe /getactivescheme) -join ' '
    if ($output -match '([0-9a-fA-F-]{36})') {
        return $matches[1].ToLowerInvariant()
    }

    return ''
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Get-Command -Name powercfg.exe -ErrorAction SilentlyContinue)) {
        throw 'powercfg.exe is not available on this device.'
    }

    if (-not $ApplyPowerPlan) {
        $message = 'Report-only mode. Set $ApplyPowerPlan to $true after pilot testing to change the active power plan.'
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message

        if ($ExitZeroInReportingOnlyMode) {
            exit 0
        }

        exit 1
    }

    & powercfg.exe /setactive $TargetPowerPlanGuid | Out-Null
    $activeGuid = Get-ActivePowerPlanGuid

    if ($activeGuid -eq $TargetPowerPlanGuid.ToLowerInvariant()) {
        Write-Output "Remediation succeeded. Active power plan is '$activeGuid'."
        exit 0
    }

    throw "Power plan validation failed. Active='$activeGuid'; Expected='$TargetPowerPlanGuid'."
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed for active power plan.'
    exit 1
}
