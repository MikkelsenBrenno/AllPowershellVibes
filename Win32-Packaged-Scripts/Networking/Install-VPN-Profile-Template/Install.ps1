<#
.SYNOPSIS
    Installs a VPN profile template.

.DESCRIPTION
    Win32 app install script example. The script creates a configurable VPN
    profile using Add-VpnConnection and validates that the profile exists.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      VPN profile installed
    Exit 1:      VPN profile install failed

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
$ScriptName = 'Install'

$VpnName = 'Example VPN Profile'
$ServerAddress = 'vpn.contoso.example'
$TunnelType = 'Automatic'
$AuthenticationMethod = 'Eap'
$EncryptionLevel = 'Required'
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

function Get-ConfiguredVpnConnection {
    if ($AllUserConnection) {
        return Get-VpnConnection -Name $VpnName -AllUserConnection -ErrorAction SilentlyContinue
    }

    return Get-VpnConnection -Name $VpnName -ErrorAction SilentlyContinue
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if ($ServerAddress -eq 'vpn.contoso.example') {
        throw 'Replace the ServerAddress placeholder before deployment.'
    }

    if (-not (Get-Command -Name Add-VpnConnection -ErrorAction SilentlyContinue)) {
        throw 'Add-VpnConnection is not available on this device.'
    }

    $existing = Get-ConfiguredVpnConnection
    if ($null -ne $existing) {
        if ($AllUserConnection) {
            Remove-VpnConnection -Name $VpnName -AllUserConnection -Force -ErrorAction Stop
        }
        else {
            Remove-VpnConnection -Name $VpnName -Force -ErrorAction Stop
        }
    }

    if ($AllUserConnection) {
        Add-VpnConnection -Name $VpnName -ServerAddress $ServerAddress -TunnelType $TunnelType -AuthenticationMethod $AuthenticationMethod -EncryptionLevel $EncryptionLevel -AllUserConnection -Force -ErrorAction Stop
    }
    else {
        Add-VpnConnection -Name $VpnName -ServerAddress $ServerAddress -TunnelType $TunnelType -AuthenticationMethod $AuthenticationMethod -EncryptionLevel $EncryptionLevel -Force -ErrorAction Stop
    }

    $vpn = Get-ConfiguredVpnConnection
    if ($null -eq $vpn) {
        throw "VPN profile '$VpnName' was not detected after install."
    }

    Write-Output "Install succeeded. VPN profile '$VpnName' was installed."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
