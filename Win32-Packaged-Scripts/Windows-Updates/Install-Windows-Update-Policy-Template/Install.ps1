<#
.SYNOPSIS
    Installs Windows Update policy registry values.

.DESCRIPTION
    Win32 app install script example. The script writes configurable Windows
    Update policy registry values and validates the final state.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Windows Update policy marker installed
    Exit 1:      Windows Update policy marker install failed

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

$ScriptPackageName = 'Install-Windows-Update-Policy-Template'
$ScriptName = 'Install'

$WindowsUpdatePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$TargetReleaseVersionInfo = 'REPLACE_WITH_TARGET_VERSION'
$ProductVersion = 'Windows 11'
$PolicyValues = @{
    TargetReleaseVersion = 1
}

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

    if ($TargetReleaseVersionInfo -eq 'REPLACE_WITH_TARGET_VERSION') {
        throw 'Replace TargetReleaseVersionInfo before deployment.'
    }

    if (-not (Test-Path -LiteralPath $WindowsUpdatePolicyPath)) {
        New-Item -Path $WindowsUpdatePolicyPath -Force | Out-Null
    }

    foreach ($name in $PolicyValues.Keys) {
        New-ItemProperty -Path $WindowsUpdatePolicyPath -Name $name -Value ([int]$PolicyValues[$name]) -PropertyType DWord -Force | Out-Null
    }

    New-ItemProperty -Path $WindowsUpdatePolicyPath -Name 'TargetReleaseVersionInfo' -Value $TargetReleaseVersionInfo -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $WindowsUpdatePolicyPath -Name 'ProductVersion' -Value $ProductVersion -PropertyType String -Force | Out-Null

    $policy = Get-ItemProperty -LiteralPath $WindowsUpdatePolicyPath -ErrorAction Stop
    if ([string]$policy.TargetReleaseVersionInfo -ne $TargetReleaseVersionInfo) {
        throw 'Windows Update policy validation failed.'
    }

    Write-Output "Install succeeded. Windows Update target release '$TargetReleaseVersionInfo' configured."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
