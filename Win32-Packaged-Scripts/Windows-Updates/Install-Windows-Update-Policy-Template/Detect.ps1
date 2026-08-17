<#
.SYNOPSIS
    Detects Windows Update policy registry values.

.DESCRIPTION
    Win32 app detection script example. The script checks configurable Windows
    Update target release policy values and writes output only when detected.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Detection
    Exit 0:      Windows Update policy detected, with STDOUT
    Exit 1:      Windows Update policy missing or incorrect

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
$ScriptName = 'Detect'

$WindowsUpdatePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$ExpectedTargetReleaseVersionInfo = 'REPLACE_WITH_TARGET_VERSION'
$ExpectedProductVersion = 'Windows 11'

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

    if (-not (Test-Path -LiteralPath $WindowsUpdatePolicyPath)) {
        exit 1
    }

    $policy = Get-ItemProperty -LiteralPath $WindowsUpdatePolicyPath -ErrorAction Stop
    if ([int]$policy.TargetReleaseVersion -eq 1 -and [string]$policy.TargetReleaseVersionInfo -eq $ExpectedTargetReleaseVersionInfo -and [string]$policy.ProductVersion -eq $ExpectedProductVersion) {
        Write-Output "Detected. Windows Update target release '$ExpectedTargetReleaseVersionInfo' is configured."
        exit 0
    }

    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    exit 1
}
