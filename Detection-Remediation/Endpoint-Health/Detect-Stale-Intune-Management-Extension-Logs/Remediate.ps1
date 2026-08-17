<#
.SYNOPSIS
    Reports stale Intune Management Extension logs.

.DESCRIPTION
    Intune Remediations remediation script. This package is reporting-only
    because stale IME logs usually indicate a service, enrollment, or
    communication issue that needs investigation.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Reporting-only success is enabled
    Exit 1:      IME log issue remains

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

$ScriptPackageName = 'Detect-Stale-Intune-Management-Extension-Logs'
$ScriptName = 'Remediate'

$ImeLogFolder = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneManagementExtension\Logs'
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

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Output "IME logs are stale or missing. Review '$ImeLogFolder' and Intune Management Extension health."
    if ($ExitZeroInReportingOnlyMode) { exit 0 }
    exit 1
}
catch {
    try { Write-Log -Message "Remediation reporting failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Reporting failed for stale IME logs.'
    exit 1
}
