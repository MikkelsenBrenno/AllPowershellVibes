<#
.SYNOPSIS
    Detects a custom Windows event log source.

.DESCRIPTION
    Win32 app custom detection script template. Intune considers the app
    detected only when this script exits 0 and writes a string to STDOUT.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Detection
    Exit 0:      Event log source detected, with STDOUT
    Exit 1:      Event log source missing or marker version mismatch

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

$ScriptPackageName = 'Install-Custom-Event-Log-Source'
$ScriptName = 'Detect'

$EventLogName = 'Application'
$EventSourceName = 'IntuneScriptLibraryExample'
$PackageVersion = '1.0.0'
$MarkerRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\EventLogSources\IntuneScriptLibraryExample'
$MarkerFileName = 'install-marker.json'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-EventSourceRegistryPath {
    Join-Path -Path "HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\$EventLogName" -ChildPath $EventSourceName
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $eventSourceRegistryPath = Get-EventSourceRegistryPath
    if (-not (Test-Path -LiteralPath $eventSourceRegistryPath -PathType Container)) {
        exit 1
    }

    $markerPath = Join-Path -Path $MarkerRoot -ChildPath $MarkerFileName
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        exit 1
    }

    $marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
    if ([string]$marker.PackageVersion -ne $PackageVersion) {
        exit 1
    }

    Write-Output "Detected. Event source '$EventSourceName' is available in '$EventLogName' with package version '$PackageVersion'."
    exit 0
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    exit 1
}
