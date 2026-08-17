<#
.SYNOPSIS
    Creates or updates expected Windows Update policy registry values.

.DESCRIPTION
    Intune Remediations remediation script. The script can create a
    customizable list of Windows Update policy registry values. It is
    report-only by default so administrators can review policy impact first.

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

$ScriptPackageName = 'Ensure-Windows-Update-Policy-Keys-Present'
$ScriptName = 'Remediate'

$ApplyRegistryChanges = $false
$ExpectedRegistryValues = @(
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        Name = 'TargetReleaseVersion'
        Type = 'DWord'
        Value = 1
    },
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        Name = 'TargetReleaseVersionInfo'
        Type = 'String'
        Value = '24H2'
    }
)

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
    Write-Log -Message "Remediation started. ApplyRegistryChanges='$ApplyRegistryChanges'."

    foreach ($item in $ExpectedRegistryValues) {
        Write-Log -Message "Target value. Path='$($item.Path)'; Name='$($item.Name)'; Type='$($item.Type)'; Value='$($item.Value)'."

        if (-not $ApplyRegistryChanges) {
            continue
        }

        if (-not (Test-Path -LiteralPath $item.Path)) {
            New-Item -Path $item.Path -Force | Out-Null
        }

        New-ItemProperty -LiteralPath $item.Path -Name $item.Name -PropertyType $item.Type -Value $item.Value -Force | Out-Null
    }

    if (-not $ApplyRegistryChanges) {
        Write-Output 'Report-only mode. Review ExpectedRegistryValues and set ApplyRegistryChanges to true after pilot testing.'
        exit 0
    }

    Write-Output 'Remediation completed. Expected Windows Update policy values were applied.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Windows Update policy values were not applied.'
    exit 1
}
