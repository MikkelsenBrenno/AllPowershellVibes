<#
.SYNOPSIS
    Discovers scheduled task last run freshness.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks whether a
    configured scheduled task exists and has run successfully within the
    configured number of days, then returns one compressed JSON object.

.NOTES
    Name:        Discover.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Custom Compliance
    Output:      Compressed JSON

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

$ScriptPackageName = 'Check-Scheduled-Task-Last-Run'
$ScriptName = 'Discover'

$TaskName = 'Example Maintenance Task'
$TaskPath = '\'
$MaximumLastRunAgeDays = 7
$ExpectedLastTaskResult = 0
$TreatNeverRunAsCompliant = $false

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

$result = [ordered]@{
    ScheduledTaskLastRunCompliant = $false
    TaskExists = $false
    TaskName = $TaskName
    TaskPath = $TaskPath
    LastRunTime = ''
    LastRunAgeDays = $null
    LastTaskResult = $null
    ExpectedLastTaskResult = $ExpectedLastTaskResult
}

try {
    Initialize-Log
    Write-ScriptMetadata

    if ($MaximumLastRunAgeDays -lt 1) {
        throw 'MaximumLastRunAgeDays must be 1 or greater.'
    }

    if (-not (Get-Command -Name Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        throw 'Get-ScheduledTask is not available on this device.'
    }

    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue
    if ($null -eq $task) {
        Write-Log -Message "Scheduled task '$TaskPath$TaskName' was not found." -Level 'WARN'
    }
    else {
        $result.TaskExists = $true
        $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop
        $result.LastTaskResult = [int]$taskInfo.LastTaskResult

        if ($null -ne $taskInfo.LastRunTime -and $taskInfo.LastRunTime.Year -gt 2000) {
            $result.LastRunTime = $taskInfo.LastRunTime.ToString('yyyy-MM-dd HH:mm:ss')
            $age = New-TimeSpan -Start $taskInfo.LastRunTime -End (Get-Date)
            $result.LastRunAgeDays = [math]::Round($age.TotalDays, 2)
            $result.ScheduledTaskLastRunCompliant = ($age.TotalDays -le $MaximumLastRunAgeDays -and [int]$taskInfo.LastTaskResult -eq $ExpectedLastTaskResult)
        }
        else {
            $result.ScheduledTaskLastRunCompliant = [bool]$TreatNeverRunAsCompliant
        }
    }

    Write-Log -Message "Discovery completed. TaskExists='$($result.TaskExists)'; LastRunAgeDays='$($result.LastRunAgeDays)'; LastTaskResult='$($result.LastTaskResult)'; Compliant='$($result.ScheduledTaskLastRunCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.ScheduledTaskLastRunCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
