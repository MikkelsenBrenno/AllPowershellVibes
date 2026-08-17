<#
.SYNOPSIS
    Exports recent event log errors.

.DESCRIPTION
    Intune platform script example. The script collects recent critical and
    error events from configurable Windows event logs and writes a JSON summary
    to a local troubleshooting folder.

.NOTES
    Name:        Export-Recent-Event-Log-Summary.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Event log summary written
    Exit 1:      Event log summary failed

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

$ScriptPackageName = 'Export-Recent-Event-Log-Summary'
$ScriptName = 'Export-Recent-Event-Log-Summary'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'RecentEventLogSummary.json'
$LogNames = @('System', 'Application')
$LookBackHours = 24
$EventLevelIds = @(1, 2)
$MaxEventsPerLog = 100
$MaxMessageLength = 500

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function ConvertTo-ShortMessage {
    param(
        [AllowNull()]
        [string]$Message
    )

    if ([string]::IsNullOrWhiteSpace($Message)) {
        return ''
    }

    $singleLine = ($Message -replace '\s+', ' ').Trim()
    if ($singleLine.Length -le $MaxMessageLength) {
        return $singleLine
    }

    return $singleLine.Substring(0, $MaxMessageLength)
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Test-Path -LiteralPath $InventoryRoot -PathType Container)) {
        New-Item -Path $InventoryRoot -ItemType Directory -Force | Out-Null
    }

    $startTime = (Get-Date).AddHours(-[math]::Abs($LookBackHours))
    $events = New-Object System.Collections.Generic.List[object]
    $logSummaries = New-Object System.Collections.Generic.List[object]

    foreach ($logName in $LogNames) {
        try {
            $filter = @{
                LogName = $logName
                StartTime = $startTime
                Level = $EventLevelIds
            }

            $logEvents = @(Get-WinEvent -FilterHashtable $filter -MaxEvents $MaxEventsPerLog -ErrorAction Stop)

            foreach ($event in $logEvents) {
                $events.Add([PSCustomObject]@{
                    LogName = [string]$event.LogName
                    TimeCreated = if ($null -ne $event.TimeCreated) { $event.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
                    Id = [int]$event.Id
                    ProviderName = [string]$event.ProviderName
                    LevelDisplayName = [string]$event.LevelDisplayName
                    Message = ConvertTo-ShortMessage -Message $event.Message
                })
            }

            $logSummaries.Add([PSCustomObject]@{
                LogName = $logName
                EventCount = $logEvents.Count
                QuerySucceeded = $true
                Error = ''
            })
        }
        catch {
            $logSummaries.Add([PSCustomObject]@{
                LogName = $logName
                EventCount = 0
                QuerySucceeded = $false
                Error = $_.Exception.Message
            })

            Write-Log -Message "Event log query failed for '$logName'. $($_.Exception.Message)" -Level 'WARN'
        }
    }

    $inventory = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        LookBackHours = [int]$LookBackHours
        EventLevelIds = $EventLevelIds
        MaxEventsPerLog = [int]$MaxEventsPerLog
        LogSummaries = @($logSummaries)
        EventCount = $events.Count
        Events = @($events | Sort-Object -Property TimeCreated -Descending)
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $inventory | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) {
        throw "Event log summary '$inventoryPath' was not created."
    }

    Write-Log -Message "Event log summary written. Path='$inventoryPath'; EventCount='$($events.Count)'."
    Write-Output "Recent event log summary written to '$inventoryPath'. EventCount='$($events.Count)'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export recent event log summary.'
    exit 1
}
