<#
.SYNOPSIS
    Detects a VPN profile.

.DESCRIPTION
    Win32 app detection script example. The script checks whether a configured
    VPN profile exists and points to the expected server address.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Detection
    Exit 0:      VPN profile detected, with STDOUT
    Exit 1:      VPN profile missing or incorrect

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

$ScriptPackageName = 'Install-VPN-Profile-Template'
$ScriptName = 'Detect'

$VpnName = 'Example VPN Profile'
$ExpectedServerAddress = 'vpn.contoso.example'
$AllUserConnection = $true

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

    if ($AllUserConnection) {
        $vpn = Get-VpnConnection -Name $VpnName -AllUserConnection -ErrorAction SilentlyContinue
    }
    else {
        $vpn = Get-VpnConnection -Name $VpnName -ErrorAction SilentlyContinue
    }

    if ($null -ne $vpn -and [string]$vpn.ServerAddress -eq $ExpectedServerAddress) {
        Write-Output "Detected. VPN profile '$VpnName' points to '$ExpectedServerAddress'."
        exit 0
    }

    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    exit 1
}
