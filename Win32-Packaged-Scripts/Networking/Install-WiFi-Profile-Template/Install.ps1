<#
.SYNOPSIS
    Installs a Wi-Fi profile from XML.

.DESCRIPTION
    Win32 app install script example. The script imports a configurable Wi-Fi
    profile XML file with netsh and validates that the profile exists.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Wi-Fi profile installed
    Exit 1:      Wi-Fi profile install failed

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

$ScriptPackageName = 'Install-WiFi-Profile-Template'
$ScriptName = 'Install'

$WiFiProfileXmlFileName = 'WiFiProfile.xml'
$WiFiProfileName = 'Contoso WiFi'
$ProfileScope = 'all'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Test-WiFiProfilePresent {
    $profileOutput = @(netsh.exe wlan show profiles) -join "`n"
    return ($profileOutput -like "*$WiFiProfileName*")
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Get-Command -Name netsh.exe -ErrorAction SilentlyContinue)) {
        throw 'netsh.exe is not available on this device.'
    }

    $profilePath = Join-Path -Path $PSScriptRoot -ChildPath $WiFiProfileXmlFileName
    if (-not (Test-Path -LiteralPath $profilePath -PathType Leaf)) {
        throw "Wi-Fi profile XML '$profilePath' was not found."
    }

    $profileRaw = Get-Content -LiteralPath $profilePath -Raw -ErrorAction Stop
    if ($profileRaw -like '*REPLACE_WITH_WIFI_PASSPHRASE*') {
        throw 'Replace the Wi-Fi passphrase placeholder in WiFiProfile.xml before deployment.'
    }

    & netsh.exe wlan add profile "filename=$profilePath" "user=$ProfileScope" | Out-Null

    if (-not (Test-WiFiProfilePresent)) {
        throw "Wi-Fi profile '$WiFiProfileName' was not detected after import."
    }

    Write-Output "Install succeeded. Wi-Fi profile '$WiFiProfileName' was imported."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
