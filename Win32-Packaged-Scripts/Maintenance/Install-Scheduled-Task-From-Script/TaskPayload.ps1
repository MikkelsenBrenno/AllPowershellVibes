<#
.SYNOPSIS
    Example scheduled task payload.

.DESCRIPTION
    Safe placeholder payload for the scheduled task Win32 package template.
    The default action writes a last-run marker so technicians can verify the
    task is executing before replacing this script with real maintenance.

.NOTES
    Name:        TaskPayload.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Payload
    Exit 0:      Payload completed
    Exit 1:      Payload failed

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

$ScriptPackageName = 'Install-Scheduled-Task-From-Script'
$ScriptName = 'TaskPayload'

$MarkerRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ScheduledTasks\ContosoExampleMaintenanceTask'
$MarkerFileName = 'last-run.txt'
$PayloadActionDescription = 'Write a last-run marker for scheduled task validation.'

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

    if (-not (Test-Path -LiteralPath $MarkerRoot -PathType Container)) {
        New-Item -Path $MarkerRoot -ItemType Directory -Force | Out-Null
    }

    $markerPath = Join-Path -Path $MarkerRoot -ChildPath $MarkerFileName
    $marker = [ordered]@{
        LastRun = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        Action = $PayloadActionDescription
    }

    $marker.GetEnumerator() |
        ForEach-Object { '{0}: {1}' -f $_.Key, $_.Value } |
        Set-Content -LiteralPath $markerPath -Encoding UTF8

    Write-Output "Payload completed. Marker written to '$markerPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Payload failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Payload failed.'
    exit 1
}
