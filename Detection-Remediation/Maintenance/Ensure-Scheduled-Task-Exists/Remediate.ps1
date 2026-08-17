<#
.SYNOPSIS
    Creates or updates a scheduled task.

.DESCRIPTION
    Intune Remediations remediation script. The script creates or updates a
    scheduled task with a configurable action, trigger, and principal.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Scheduled task exists and validates
    Exit 1:      Scheduled task could not be created or validated

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

$ScriptPackageName = 'Ensure-Scheduled-Task-Exists'
$ScriptName = 'Remediate'

$TaskName = 'IntuneScriptLibraryExample'
$TaskPath = '\IntuneScriptLibrary\'
$TaskDescription = 'Example scheduled task created by Intune Script Library.'
$ActionExecutable = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$ActionArguments = '-NoProfile -ExecutionPolicy Bypass -Command "Write-Output ''IntuneScriptLibraryExample''"'
$TriggerType = 'AtStartup'
$RunAsUserId = 'SYSTEM'
$RunLevel = 'Highest'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

function New-ConfiguredTrigger {
    switch ($TriggerType) {
        'AtStartup' { return New-ScheduledTaskTrigger -AtStartup }
        'AtLogOn' { return New-ScheduledTaskTrigger -AtLogOn }
        default { throw "TriggerType '$TriggerType' is not valid. Use AtStartup or AtLogOn." }
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. TaskPath='$TaskPath'; TaskName='$TaskName'; TriggerType='$TriggerType'."

    foreach ($commandName in @('New-ScheduledTaskAction', 'New-ScheduledTaskTrigger', 'New-ScheduledTaskPrincipal', 'Register-ScheduledTask', 'Get-ScheduledTask')) {
        if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
            throw "$commandName is not available on this device."
        }
    }

    $action = New-ScheduledTaskAction -Execute $ActionExecutable -Argument $ActionArguments
    $trigger = New-ConfiguredTrigger
    $principal = New-ScheduledTaskPrincipal -UserId $RunAsUserId -RunLevel $RunLevel

    Register-ScheduledTask `
        -TaskName $TaskName `
        -TaskPath $TaskPath `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Description $TaskDescription `
        -Force | Out-Null

    $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
    $createdAction = @($task.Actions)[0]

    if ($createdAction.Execute -eq $ActionExecutable -and $createdAction.Arguments -eq $ActionArguments) {
        $message = "Remediation succeeded. Scheduled task '$TaskPath$TaskName' is configured."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    throw "Scheduled task validation failed for '$TaskPath$TaskName'."
}
catch {
    try {
        Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output "Remediation failed for scheduled task '$TaskPath$TaskName'."
    exit 1
}
