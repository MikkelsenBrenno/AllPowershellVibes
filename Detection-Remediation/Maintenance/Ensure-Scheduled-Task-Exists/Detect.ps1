<#
.SYNOPSIS
    Detects whether a scheduled task exists with the expected action.

.DESCRIPTION
    Intune Remediations detection script. The script checks a configurable
    scheduled task name, path, executable, and arguments.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Scheduled task exists and matches expected action
    Exit 1:      Scheduled task is missing or different

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
$ScriptName = 'Detect'

$TaskName = 'IntuneScriptLibraryExample'
$TaskPath = '\IntuneScriptLibrary\'
$ExpectedActionExecutable = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$ExpectedActionArguments = '-NoProfile -ExecutionPolicy Bypass -Command "Write-Output ''IntuneScriptLibraryExample''"'

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

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. TaskPath='$TaskPath'; TaskName='$TaskName'."

    if (-not (Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        throw 'Get-ScheduledTask is not available on this device.'
    }

    $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
    $action = @($task.Actions)[0]

    Write-Log -Message "Task action. Execute='$($action.Execute)'; Arguments='$($action.Arguments)'."

    if ($action.Execute -eq $ExpectedActionExecutable -and $action.Arguments -eq $ExpectedActionArguments) {
        $message = "Compliant. Scheduled task '$TaskPath$TaskName' exists with the expected action."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Scheduled task '$TaskPath$TaskName' action does not match expected values."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output "Not compliant. Scheduled task '$TaskPath$TaskName' could not be validated."
    exit 1
}
