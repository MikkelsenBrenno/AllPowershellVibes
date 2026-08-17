<#
.SYNOPSIS
    Uninstalls a packaged scheduled task.

.DESCRIPTION
    Win32 app uninstall script template. The script unregisters the scheduled
    task and can remove the installed payload folder.

.NOTES
    Name:        Uninstall.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Scheduled task removed or already absent
    Exit 1:      Scheduled task uninstall failed

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
$ScriptName = 'Uninstall'

$TaskName = 'Contoso Example Maintenance Task'
$TaskPath = '\IntuneScriptLibrary\'
$InstallRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ScheduledTasks\ContosoExampleMaintenanceTask'
$RemovePayloadFolder = $true

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
    $registeredTask = Get-ScheduledTask -TaskName $TaskName -TaskPath $normalizedTaskPath -ErrorAction SilentlyContinue

    if ($null -ne $registeredTask) {
        Unregister-ScheduledTask -TaskName $TaskName -TaskPath $normalizedTaskPath -Confirm:$false
        Write-Log -Message "Removed scheduled task '$normalizedTaskPath$TaskName'."
    }
    else {
        Write-Log -Message "Scheduled task '$normalizedTaskPath$TaskName' was already absent."
    }

    if ($RemovePayloadFolder -and (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        Remove-Item -LiteralPath $InstallRoot -Recurse -Force
        Write-Log -Message "Removed payload folder '$InstallRoot'."
    }

    Write-Output "Uninstall succeeded. Scheduled task '$normalizedTaskPath$TaskName' is absent."
    exit 0
}
catch {
    try { Write-Log -Message "Uninstall failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Uninstall failed.'
    exit 1
}
