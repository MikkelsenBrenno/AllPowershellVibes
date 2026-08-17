<#
.SYNOPSIS
    Exports Defender Network Inspection Service state.

.DESCRIPTION
    Intune platform script that exports defender network inspection service state to a local JSON file for Business Premium troubleshooting.

.NOTES
    Name:        Export-BP-defender-network-inspection-Service-State.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune Platform Script
    Exit 0:      Troubleshooting snapshot exported
    Exit 1:      Troubleshooting snapshot export failed

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
$ScriptPackageName = 'Export-BP-defender-network-inspection-Service-State'
$ScriptName = 'Export-BP-defender-network-inspection-Service-State'

$OutputRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$OutputFileName = 'BPPlatformdefendernetworkinspectionServiceSnapshot.json'
$JsonDepth = 8
$CollectionMode = 'Service'

$RegistryItems = @()
$ServiceNames = @()
$FolderPaths = @()
$EventLogName = ''
$RecentEventCount = 50
$EventIdsToHighlight = @()
$TaskNamePatterns = @()
$TaskPathPrefix = '\'
$SnapshotNote = 'Defender Network Inspection service state snapshot for technician troubleshooting.'

$ServiceNames = @('WdNisSvc')

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

    if (-not (Test-Path -LiteralPath $OutputRoot)) {
        New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null
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

function Get-RegistrySnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Items
    )

    foreach ($item in $Items) {
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
    param(
        [Parameter(Mandatory = $true)]
        [array]$Names
    )

    foreach ($name in $Names) {
        $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            [pscustomobject]@{
                Name = $name
                Exists = $false
                DisplayName = ''
                State = ''
                StartMode = ''
                Status = ''
                StartName = ''
                PathName = ''
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
                StartName = $service.StartName
                PathName = $service.PathName
            }
        }
    }
}

function Get-FolderSnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Paths
    )

    foreach ($rawPath in $Paths) {
        $path = [Environment]::ExpandEnvironmentVariables($rawPath)
        $exists = Test-Path -LiteralPath $path
        $fileCount = 0
        $folderCount = 0
        $totalBytes = [int64]0
        $oldestWrite = $null
        $newestWrite = $null

        if ($exists) {
            $items = @(Get-ChildItem -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue)
            $files = @($items | Where-Object { -not $_.PSIsContainer })
            $folders = @($items | Where-Object { $_.PSIsContainer })
            $fileCount = $files.Count
            $folderCount = $folders.Count
            foreach ($file in $files) {
                $totalBytes += [int64]$file.Length
            }
            $sortedDates = @($items | Where-Object { $null -ne $_.LastWriteTime } | Sort-Object -Property LastWriteTime)
            if ($sortedDates.Count -gt 0) {
                $oldestWrite = $sortedDates[0].LastWriteTime.ToString('o')
                $newestWrite = $sortedDates[-1].LastWriteTime.ToString('o')
            }
        }

        [pscustomobject]@{
            Path = $path
            Exists = $exists
            FileCount = $fileCount
            FolderCount = $folderCount
            TotalMB = Convert-BytesToMB -Value $totalBytes
            OldestLastWriteTime = $oldestWrite
            NewestLastWriteTime = $newestWrite
        }
    }
}

function Get-EventSnapshot {
    if ([string]::IsNullOrWhiteSpace($EventLogName)) {
        return @()
    }

    $events = @(Get-WinEvent -LogName $EventLogName -MaxEvents $RecentEventCount -ErrorAction SilentlyContinue | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message)
    $highlighted = @($events | Where-Object { $EventIdsToHighlight -contains $_.Id })

    return [pscustomobject]@{
        LogName = $EventLogName
        RecentEventCount = $RecentEventCount
        EventIdsToHighlight = $EventIdsToHighlight
        HighlightedEvents = $highlighted
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

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Platform script started. CollectionMode='$CollectionMode'."

    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        CapturedAt = (Get-Date).ToString('o')
        CollectionMode = $CollectionMode
        SnapshotNote = $SnapshotNote
    }

    switch ($CollectionMode) {
        'Registry' { $payload.RegistryState = @(Get-RegistrySnapshot -Items $RegistryItems) }
        'Service' { $payload.ServiceState = @(Get-ServiceSnapshot -Names $ServiceNames) }
        'Folder' { $payload.FolderState = @(Get-FolderSnapshot -Paths $FolderPaths) }
        'Event' { $payload.EventState = Get-EventSnapshot }
        'Task' { $payload.TaskState = @(Get-TaskSnapshot) }
        default { throw "CollectionMode '$CollectionMode' is not supported." }
    }

    $outputPath = Join-Path -Path $OutputRoot -ChildPath $OutputFileName
    $payload | ConvertTo-Json -Depth $JsonDepth | Set-Content -LiteralPath $outputPath -Encoding UTF8

    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw "Output file '$outputPath' was not created."
    }

    Write-Log -Message "Platform script completed. Output='$outputPath'."
    Write-Output "Troubleshooting snapshot exported to '$outputPath'."
    exit 0
}
catch {
    try {
        Write-Log -Message "Platform script failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Troubleshooting snapshot export failed.'
    exit 1
}

