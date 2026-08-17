<#
.SYNOPSIS
    Detects a VPN profile.

.DESCRIPTION
    Intune Remediations detection script. The script checks for a configurable
    Windows VPN profile using Get-VpnConnection.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System or user, depending on VPN profile scope

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      VPN profile exists
    Exit 1:      VPN profile is missing

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

$ScriptPackageName = 'Detect-VPN-Profile'
$ScriptName = 'Detect'

$VpnConnectionName = 'Contoso VPN'
$CheckAllUserConnection = $true

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

    if (-not (Get-Command -Name Get-VpnConnection -ErrorAction SilentlyContinue)) {
        throw 'Get-VpnConnection is not available.'
    }

    $vpnConnection = Get-VpnConnection -Name $VpnConnectionName -AllUserConnection:$CheckAllUserConnection -ErrorAction SilentlyContinue

    if ($null -ne $vpnConnection) {
        Write-Output "Compliant. VPN profile '$VpnConnectionName' exists."
        exit 0
    }

    Write-Output "Not compliant. VPN profile '$VpnConnectionName' is missing."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. VPN profile '$VpnConnectionName' could not be validated."
    exit 1
}
