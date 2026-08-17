<#
.SYNOPSIS
    Configures OneDrive Known Folder Move policy.

.DESCRIPTION
    Intune platform script example. The script can configure OneDrive Known
    Folder Move policy registry values for prompting or silently moving known
    folders after an explicit ApplyPolicy switch is enabled.

.NOTES
    Name:        Configure-OneDrive-Known-Folder-Move.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Platform Script
    Exit 0:      Policy applied or reporting-only success enabled
    Exit 1:      Policy was not applied

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

$ScriptPackageName = 'Configure-OneDrive-Known-Folder-Move'
$ScriptName = 'Configure-OneDrive-Known-Folder-Move'

$OneDrivePolicyRoot = 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive'
$TenantId = '00000000-0000-0000-0000-000000000000'
$KfmMode = 'Prompt'
$PreventUsersFromOptingOut = $true
$ApplyPolicy = $false
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

    if ($KfmMode -notin @('Prompt', 'Silent')) {
        throw "Unsupported KfmMode '$KfmMode'. Use 'Prompt' or 'Silent'."
    }

    if (-not $ApplyPolicy) {
        Write-Output "OneDrive KFM policy would be configured for mode '$KfmMode', but ApplyPolicy is disabled."
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    if ($TenantId -eq '00000000-0000-0000-0000-000000000000') {
        throw 'Replace the TenantId placeholder before enabling ApplyPolicy.'
    }

    if (-not (Test-Path -LiteralPath $OneDrivePolicyRoot -PathType Container)) {
        New-Item -Path $OneDrivePolicyRoot -ItemType Directory -Force | Out-Null
    }

    if ($KfmMode -eq 'Prompt') {
        New-ItemProperty -Path $OneDrivePolicyRoot -Name 'KFMOptInWithWizard' -Value $TenantId -PropertyType String -Force | Out-Null
        Remove-ItemProperty -LiteralPath $OneDrivePolicyRoot -Name 'KFMOptInNoWizard' -ErrorAction SilentlyContinue
    }
    else {
        New-ItemProperty -Path $OneDrivePolicyRoot -Name 'KFMOptInNoWizard' -Value $TenantId -PropertyType String -Force | Out-Null
        Remove-ItemProperty -LiteralPath $OneDrivePolicyRoot -Name 'KFMOptInWithWizard' -ErrorAction SilentlyContinue
    }

    if ($PreventUsersFromOptingOut) {
        New-ItemProperty -Path $OneDrivePolicyRoot -Name 'KFMBlockOptOut' -Value 1 -PropertyType DWord -Force | Out-Null
    }

    Write-Output "OneDrive Known Folder Move policy configured. Mode='$KfmMode'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "OneDrive KFM policy was not configured."
    exit 1
}
