<#
.SYNOPSIS
    Installs a scheduled task from a packaged script.

.DESCRIPTION
    Win32 app install script template. The script copies a payload PowerShell
    script to ProgramData and registers a scheduled task that runs the payload
    on a configurable schedule.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Scheduled task installed
    Exit 1:      Scheduled task install failed

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
$ScriptName = 'Install'

$TaskName = 'Contoso Example Maintenance Task'
$TaskPath = '\IntuneScriptLibrary\'
$TaskDescription = 'Example Intune Script Library scheduled task. Customize before production deployment.'
$PayloadScriptFileName = 'TaskPayload.ps1'
$InstallRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ScheduledTasks\ContosoExampleMaintenanceTask'
$RunAsAccount = 'SYSTEM'
$ScheduleFrequency = 'Daily'
$StartTime = '03:00'

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

function New-ConfiguredScheduledTaskTrigger {
    switch ($ScheduleFrequency) {
        'Daily' {
            $parsedStartTime = [datetime]::ParseExact($StartTime, 'HH:mm', [System.Globalization.CultureInfo]::InvariantCulture)
            return New-ScheduledTaskTrigger -Daily -At $parsedStartTime
        }
        'AtLogon' {
            return New-ScheduledTaskTrigger -AtLogOn
        }
        default {
            throw "Unsupported ScheduleFrequency '$ScheduleFrequency'. Use 'Daily' or 'AtLogon'."
        }
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $normalizedTaskPath = Get-NormalizedTaskPath -Path $TaskPath
    $sourcePayloadPath = Join-Path -Path $PSScriptRoot -ChildPath $PayloadScriptFileName
    $installedPayloadPath = Join-Path -Path $InstallRoot -ChildPath $PayloadScriptFileName

    if (-not (Test-Path -LiteralPath $sourcePayloadPath -PathType Leaf)) {
        throw "Payload script '$sourcePayloadPath' was not found in the Win32 package."
    }

    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        New-Item -Path $InstallRoot -ItemType Directory -Force | Out-Null
    }

    Copy-Item -LiteralPath $sourcePayloadPath -Destination $installedPayloadPath -Force

    $powershellPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $actionArguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $installedPayloadPath
    $action = New-ScheduledTaskAction -Execute $powershellPath -Argument $actionArguments
    $trigger = New-ConfiguredScheduledTaskTrigger
    $principal = New-ScheduledTaskPrincipal -UserId $RunAsAccount -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -Compatibility Win8 -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

    Register-ScheduledTask `
        -TaskName $TaskName `
        -TaskPath $normalizedTaskPath `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Settings $settings `
        -Description $TaskDescription `
        -Force | Out-Null

    $registeredTask = Get-ScheduledTask -TaskName $TaskName -TaskPath $normalizedTaskPath -ErrorAction SilentlyContinue
    if ($null -eq $registeredTask) {
        throw "Scheduled task '$normalizedTaskPath$TaskName' was not found after registration."
    }

    if (-not (Test-Path -LiteralPath $installedPayloadPath -PathType Leaf)) {
        throw "Installed payload script '$installedPayloadPath' was not found after copy."
    }

    Write-Output "Install succeeded. Scheduled task '$normalizedTaskPath$TaskName' is installed."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
