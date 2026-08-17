<#
.SYNOPSIS
    Uninstalls a custom Windows event log source.

.DESCRIPTION
    Win32 app uninstall script template. The script removes the version marker
    and can optionally remove the configured event source.

.NOTES
    Name:        Uninstall.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Event log source marker removed
    Exit 1:      Event log source uninstall failed

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
$ScriptName = 'Uninstall'

$EventSourceName = 'IntuneScriptLibraryExample'
$MarkerRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\EventLogSources\IntuneScriptLibraryExample'
$MarkerFileName = 'install-marker.json'
$RemoveEventSource = $false
$RemoveMarkerRoot = $true

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

    if ($RemoveEventSource -and [System.Diagnostics.EventLog]::SourceExists($EventSourceName)) {
        Remove-EventLog -Source $EventSourceName -ErrorAction Stop
        Write-Log -Message "Removed event source '$EventSourceName'."
    }

    $markerPath = Join-Path -Path $MarkerRoot -ChildPath $MarkerFileName
    if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
        Remove-Item -LiteralPath $markerPath -Force
        Write-Log -Message "Removed marker '$markerPath'."
    }

    if ($RemoveMarkerRoot -and (Test-Path -LiteralPath $MarkerRoot -PathType Container)) {
        $remainingItems = @(Get-ChildItem -LiteralPath $MarkerRoot -Force -ErrorAction SilentlyContinue)
        if ($remainingItems.Count -eq 0) {
            Remove-Item -LiteralPath $MarkerRoot -Force
            Write-Log -Message "Removed marker folder '$MarkerRoot'."
        }
    }

    Write-Output "Uninstall succeeded. Event log source marker for '$EventSourceName' is absent."
    exit 0
}
catch {
    try { Write-Log -Message "Uninstall failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Uninstall failed.'
    exit 1
}
