<#
.SYNOPSIS
    Installs a custom Windows event log source.

.DESCRIPTION
    Win32 app install script template. The script creates a configurable
    Windows event log source and writes a versioned marker file for reliable
    Intune detection.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Event log source installed
    Exit 1:      Event log source install failed

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
$ScriptName = 'Install'

$EventLogName = 'Application'
$EventSourceName = 'IntuneScriptLibraryExample'
$PackageVersion = '1.0.0'
$MarkerRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\EventLogSources\IntuneScriptLibraryExample'
$MarkerFileName = 'install-marker.json'
$WriteTestEvent = $false
$TestEventId = 1000

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

    if (-not [System.Diagnostics.EventLog]::SourceExists($EventSourceName)) {
        New-EventLog -LogName $EventLogName -Source $EventSourceName -ErrorAction Stop
        Write-Log -Message "Created event source '$EventSourceName' in log '$EventLogName'."
    }
    else {
        Write-Log -Message "Event source '$EventSourceName' already exists."
    }

    $eventSourceRegistryPath = Get-EventSourceRegistryPath
    if (-not (Test-Path -LiteralPath $eventSourceRegistryPath -PathType Container)) {
        throw "Event source registry path '$eventSourceRegistryPath' was not found."
    }

    if ($WriteTestEvent) {
        Write-EventLog -LogName $EventLogName -Source $EventSourceName -EntryType Information -EventId $TestEventId -Message "Test event from $ScriptPackageName version $PackageVersion." -ErrorAction Stop
    }

    if (-not (Test-Path -LiteralPath $MarkerRoot -PathType Container)) {
        New-Item -Path $MarkerRoot -ItemType Directory -Force | Out-Null
    }

    $markerPath = Join-Path -Path $MarkerRoot -ChildPath $MarkerFileName
    $marker = [ordered]@{
        PackageName = $ScriptPackageName
        PackageVersion = $PackageVersion
        EventLogName = $EventLogName
        EventSourceName = $EventSourceName
        InstalledAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    }

    $marker | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $markerPath -Encoding UTF8

    Write-Output "Install succeeded. Event source '$EventSourceName' is available in '$EventLogName'."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
