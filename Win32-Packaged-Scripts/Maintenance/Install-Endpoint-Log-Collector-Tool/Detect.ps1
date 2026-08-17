<#
.SYNOPSIS
    Detects whether the endpoint log collector helper script is installed.

.DESCRIPTION
    Win32 app detection script. The script checks the installed collector file
    and marker version.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Collector detected
    Exit 1:      Collector missing or version mismatch

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
$ScriptName = 'Detect'

$CollectorScriptName = 'Collect-EndpointLogs.ps1'
$InstallRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Tools\EndpointLogCollector'
$MarkerFileName = 'EndpointLogCollector.version'
$ExpectedVersion = '1.0.0'

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

    $collectorPath = Join-Path -Path $InstallRoot -ChildPath $CollectorScriptName
    $markerPath = Join-Path -Path $InstallRoot -ChildPath $MarkerFileName

    if (-not (Test-Path -LiteralPath $collectorPath -PathType Leaf)) {
        Write-Output "Not detected. Collector script missing at '$collectorPath'."
        exit 1
    }

    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        Write-Output "Not detected. Marker file missing at '$markerPath'."
        exit 1
    }

    $installedVersion = (Get-Content -LiteralPath $markerPath -Raw).Trim()
    if ($installedVersion -ne $ExpectedVersion) {
        Write-Output "Not detected. Expected version '$ExpectedVersion' but found '$installedVersion'."
        exit 1
    }

    Write-Output "Detected. Endpoint log collector version '$ExpectedVersion' is installed."
    exit 0
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not detected. Endpoint log collector detection failed.'
    exit 1
}
