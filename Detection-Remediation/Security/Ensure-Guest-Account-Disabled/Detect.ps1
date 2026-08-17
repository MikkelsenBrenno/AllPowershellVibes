<#
.SYNOPSIS
    Detects whether the built-in Guest account is disabled.

.DESCRIPTION
    Intune Remediations detection script. The script locates the built-in
    local Guest account by SID ending in -501 and exits 1 when it is enabled
    or cannot be validated.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Guest account is disabled
    Exit 1:      Guest account is enabled or cannot be validated

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

$ScriptPackageName = 'Ensure-Guest-Account-Disabled'
$ScriptName = 'Detect'

$GuestSidSuffix = '-501'
$ExpectedGuestEnabledState = $false

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-BuiltInGuestAccount {
    Get-CimInstance -ClassName Win32_UserAccount -Filter 'LocalAccount=True' -ErrorAction Stop |
        Where-Object { [string]$_.SID -like "*$GuestSidSuffix" } |
        Select-Object -First 1
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $guestAccount = Get-BuiltInGuestAccount
    if ($null -eq $guestAccount) {
        Write-Output "Not compliant. Built-in Guest account with SID suffix '$GuestSidSuffix' was not found."
        exit 1
    }

    $enabled = -not [bool]$guestAccount.Disabled

    if ($enabled -eq $ExpectedGuestEnabledState) {
        Write-Output "Compliant. Guest account '$($guestAccount.Name)' Enabled='$enabled'."
        exit 0
    }

    Write-Output "Not compliant. Guest account '$($guestAccount.Name)' Enabled='$enabled'."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Guest account state could not be validated.'
    exit 1
}
