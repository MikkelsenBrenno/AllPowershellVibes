<#
.SYNOPSIS
    Remediates Edge Download Restrictions state.

.DESCRIPTION
    Detects and remediates Edge Download Restrictions state for Intune-managed Windows devices.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Edge Download Restrictions remediation completed
    Exit 1:      Edge Download Restrictions remediation failed

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

$ScriptPackageName = 'Ensure-Edge-Download-Restrictions'
$ScriptName = 'Remediate'

$ManagedSettingName = 'Edge Download Restrictions'
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$ValueName = 'EdgeDownloadRestrictions'
$ExpectedValue = 'Enabled'

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

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. ManagedSettingName='$ManagedSettingName'; RegistryPath='$RegistryPath'; ValueName='$ValueName'; ExpectedValue='$ExpectedValue'."

    if (-not (Test-Path -LiteralPath $RegistryPath -PathType Container)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }

    New-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -Value $ExpectedValue -PropertyType String -Force | Out-Null
    Write-Output "Remediation completed. '$ManagedSettingName' was set to '$ExpectedValue'."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation failed for '$ManagedSettingName'."
    exit 1
}
