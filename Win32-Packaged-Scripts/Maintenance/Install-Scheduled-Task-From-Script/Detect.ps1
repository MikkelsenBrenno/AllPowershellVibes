<#
.SYNOPSIS
    Detects a packaged scheduled task.

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
    Exit 0:      Scheduled task and payload detected, with STDOUT
    Exit 1:      Scheduled task or payload missing

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
$ScriptName = 'Detect'

$TaskName = 'Contoso Example Maintenance Task'
$TaskPath = '\IntuneScriptLibrary\'
$PayloadScriptFileName = 'TaskPayload.ps1'
$InstallRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ScheduledTasks\ContosoExampleMaintenanceTask'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-NormalizedTaskPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not $Path.StartsWith('\')) {
        $Path = "\$Path"
    }

    if (-not $Path.EndsWith('\')) {
        $Path = "$Path\"
    }

    return $Path
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $normalizedTaskPath = Get-NormalizedTaskPath -Path $TaskPath
    $installedPayloadPath = Join-Path -Path $InstallRoot -ChildPath $PayloadScriptFileName
    $registeredTask = Get-ScheduledTask -TaskName $TaskName -TaskPath $normalizedTaskPath -ErrorAction SilentlyContinue

    if ($null -eq $registeredTask) {
        exit 1
    }

    if (-not (Test-Path -LiteralPath $installedPayloadPath -PathType Leaf)) {
        exit 1
    }

    Write-Output "Detected. Scheduled task '$normalizedTaskPath$TaskName' and payload '$installedPayloadPath' are present."
    exit 0
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    exit 1
}
