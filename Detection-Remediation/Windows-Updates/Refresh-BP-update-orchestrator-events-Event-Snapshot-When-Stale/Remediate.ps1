<#
.SYNOPSIS
    Refreshes the Update Orchestrator Events Event snapshot.

.DESCRIPTION
    Intune Remediations remediation script. The script writes a local JSON
    troubleshooting snapshot for technicians and validates that the file was
    created.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Snapshot refreshed
    Exit 1:      Snapshot refresh failed

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

# Keep these names aligned with the folder and script file.
# Logs are written to Logs\<ScriptPackageName>\<ScriptName>.log.
$ScriptPackageName = 'Refresh-BP-update-orchestrator-events-Event-Snapshot-When-Stale'
$ScriptName = 'Remediate'

$SnapshotRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\RemediationSnapshots'
$SnapshotFileName = 'BPupdateorchestratoreventsEventSnapshot.json'
$CollectionMode = 'Event'
$JsonDepth = 8
$RegistryItems = @()
$ServiceNames = @()
$FolderPaths = @()
$EventLogName = ''
$RecentEventCount = 50
$EventIdsToHighlight = @()
$TaskPathPrefix = '\'
$TaskNamePatterns = @()
$SnapshotNote = 'Update Orchestrator Events event log snapshot for technician troubleshooting.'

$EventLogName = 'Microsoft-Windows-UpdateOrchestrator/Operational'
$RecentEventCount = 80
$EventIdsToHighlight = @(1, 2, 3, 4, 5)

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

    if (-not (Test-Path -LiteralPath $SnapshotRoot)) {
        New-Item -Path $SnapshotRoot -ItemType Directory -Force | Out-Null
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

function Convert-BytesToMB {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    return [math]::Round(([double]$Value / 1MB), 2)
}

function ConvertTo-StringArray {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return @()
    }

    return @($Value | ForEach-Object { [string]$_ })
}

function Get-RegistrySnapshot {
    foreach ($item in $RegistryItems) {
        $exists = Test-Path -LiteralPath $item.Path
        $value = $null

        if ($exists -and -not [string]::IsNullOrWhiteSpace($item.Name)) {
            $property = Get-ItemProperty -LiteralPath $item.Path -Name $item.Name -ErrorAction SilentlyContinue
            if ($null -ne $property) {
                $value = $property.($item.Name)
            }
        }

        [pscustomobject]@{
            Path = $item.Path
            Name = $item.Name
            Exists = $exists
            Value = $value
            Description = $item.Description
        }
    }
}

function Get-ServiceSnapshot {
    foreach ($name in $ServiceNames) {
        $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            [pscustomobject]@{
                Name = $name
                Exists = $false
                DisplayName = ''
                State = ''
                StartMode = ''
                Status = ''
            }
        }
        else {
            [pscustomobject]@{
                Name = $service.Name
                Exists = $true
                DisplayName = $service.DisplayName
                State = $service.State
                StartMode = $service.StartMode
                Status = $service.Status
            }
        }
    }
}

function Get-FolderSnapshot {
    foreach ($rawPath in $FolderPaths) {
        $path = [Environment]::ExpandEnvironmentVariables($rawPath)
        $exists = Test-Path -LiteralPath $path
        $fileCount = 0
        $folderCount = 0
        $totalBytes = [int64]0

        if ($exists) {
            $items = @(Get-ChildItem -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue)
            $files = @($items | Where-Object { -not $_.PSIsContainer })
            $folders = @($items | Where-Object { $_.PSIsContainer })
            $fileCount = $files.Count
            $folderCount = $folders.Count
            foreach ($file in $files) {
                $totalBytes += [int64]$file.Length
            }
        }

        [pscustomobject]@{
            Path = $path
            Exists = $exists
            FileCount = $fileCount
            FolderCount = $folderCount
            TotalMB = Convert-BytesToMB -Value $totalBytes
        }
    }
}

function Get-EventSnapshot {
    if ([string]::IsNullOrWhiteSpace($EventLogName)) {
        return @()
    }

    $events = @(Get-WinEvent -LogName $EventLogName -MaxEvents $RecentEventCount -ErrorAction SilentlyContinue | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message)
    return [pscustomobject]@{
        LogName = $EventLogName
        RecentEventCount = $RecentEventCount
        EventIdsToHighlight = $EventIdsToHighlight
        HighlightedEvents = @($events | Where-Object { $EventIdsToHighlight -contains $_.Id })
        RecentEvents = $events
    }
}

function Get-TaskSnapshot {
    $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue)

    if (-not [string]::IsNullOrWhiteSpace($TaskPathPrefix) -and $TaskPathPrefix -ne '\') {
        $tasks = @($tasks | Where-Object { $_.TaskPath -like "$TaskPathPrefix*" })
    }

    if ($TaskNamePatterns.Count -gt 0) {
        $tasks = @($tasks | Where-Object {
            $taskText = "$($_.TaskPath)$($_.TaskName)"
            foreach ($pattern in $TaskNamePatterns) {
                if ($taskText -like $pattern) {
                    return $true
                }
            }
            return $false
        })
    }

    return @($tasks | Sort-Object -Property TaskPath, TaskName | Select-Object TaskName, TaskPath, State, Author, Description)
}

function Get-ScriptBlockSnapshot {
    if ($null -eq $CollectorScript) {
        throw 'CollectorScript is not configured.'
    }

    return & $CollectorScript
}

function New-SnapshotPayload {
    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        CapturedAt = (Get-Date).ToString('o')
        CollectionMode = $CollectionMode
        SnapshotNote = $SnapshotNote
    }

    switch ($CollectionMode) {
        'Registry' { $payload.Data = @(Get-RegistrySnapshot) }
        'Service' { $payload.Data = @(Get-ServiceSnapshot) }
        'Folder' { $payload.Data = @(Get-FolderSnapshot) }
        'Event' { $payload.Data = Get-EventSnapshot }
        'Task' { $payload.Data = @(Get-TaskSnapshot) }
        'ScriptBlock' { $payload.Data = Get-ScriptBlockSnapshot }
        default { throw "CollectionMode '$CollectionMode' is not supported." }
    }

    return $payload
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. SnapshotFileName='$SnapshotFileName'; CollectionMode='$CollectionMode'."

    $snapshotPath = Join-Path -Path $SnapshotRoot -ChildPath $SnapshotFileName
    $payload = New-SnapshotPayload
    $payload | ConvertTo-Json -Depth $JsonDepth | Set-Content -LiteralPath $snapshotPath -Encoding UTF8

    if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) {
        throw "Snapshot '$snapshotPath' was not created."
    }

    $message = "Remediation succeeded. Snapshot refreshed at '$snapshotPath'."
    Write-Log -Message $message
    Write-Output $message
    exit 0
}
catch {
    try {
        Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Remediation failed to refresh troubleshooting snapshot.'
    exit 1
}

