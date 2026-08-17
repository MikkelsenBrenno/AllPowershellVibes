<#
.SYNOPSIS
    Installs the endpoint log collector helper script.

.DESCRIPTION
    Win32 app install script. The script copies the collector payload to a
    configurable ProgramData folder and writes a marker file for Intune
    detection.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Collector installed
    Exit 1:      Collector install failed

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

$ScriptPackageName = 'Install-Endpoint-Log-Collector-Tool'
$ScriptName = 'Install'

$CollectorScriptName = 'Collect-EndpointLogs.ps1'
$InstallRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Tools\EndpointLogCollector'
$MarkerFileName = 'EndpointLogCollector.version'
$Version = '1.0.0'

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

    $sourceScript = Join-Path -Path $PSScriptRoot -ChildPath $CollectorScriptName
    $destinationScript = Join-Path -Path $InstallRoot -ChildPath $CollectorScriptName
    $markerPath = Join-Path -Path $InstallRoot -ChildPath $MarkerFileName

    if (-not (Test-Path -LiteralPath $sourceScript -PathType Leaf)) {
        throw "Collector script '$sourceScript' was not found in the Win32 package."
    }

    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        New-Item -Path $InstallRoot -ItemType Directory -Force | Out-Null
    }

    Copy-Item -LiteralPath $sourceScript -Destination $destinationScript -Force
    Set-Content -LiteralPath $markerPath -Value $Version -Encoding UTF8

    Write-Log -Message "Collector installed. Path='$destinationScript'; Version='$Version'."
    Write-Output "Install succeeded. Endpoint log collector version '$Version' is installed."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
