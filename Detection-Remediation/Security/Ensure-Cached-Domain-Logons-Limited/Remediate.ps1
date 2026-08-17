<#
.SYNOPSIS
    Limits cached domain logons.

.DESCRIPTION
    Intune Remediations remediation script. The script can set the Winlogon
    CachedLogonsCount registry value to a configured target. It is report-only
    by default because authentication settings should be piloted carefully.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation completed or report-only mode completed
    Exit 1:      Remediation failed

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

$ScriptPackageName = 'Ensure-Cached-Domain-Logons-Limited'
$ScriptName = 'Remediate'

$WinlogonRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$CachedLogonsValueName = 'CachedLogonsCount'
$TargetCachedLogonsCount = 10
$ApplyRegistryChange = $false

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
    Write-Log -Message "Remediation started. ApplyRegistryChange='$ApplyRegistryChange'; Target='$TargetCachedLogonsCount'."

    if (-not $ApplyRegistryChange) {
        Write-Output "Report-only mode. Would set '$WinlogonRegistryPath\$CachedLogonsValueName' to '$TargetCachedLogonsCount'."
        exit 0
    }

    if (-not (Test-Path -LiteralPath $WinlogonRegistryPath)) {
        New-Item -Path $WinlogonRegistryPath -Force | Out-Null
    }

    New-ItemProperty -LiteralPath $WinlogonRegistryPath -Name $CachedLogonsValueName -PropertyType String -Value ([string]$TargetCachedLogonsCount) -Force | Out-Null
    Write-Output 'Remediation completed. Cached domain logon count was updated.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Cached domain logon count was not changed.'
    exit 1
}
