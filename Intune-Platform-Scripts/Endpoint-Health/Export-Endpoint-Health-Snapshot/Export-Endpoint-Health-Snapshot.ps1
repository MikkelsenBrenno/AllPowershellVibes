<#
.SYNOPSIS
    Exports a local endpoint health snapshot.

.DESCRIPTION
    Intune platform script example. The script collects uptime, disk, memory,
    service, and recent event details, then writes a JSON snapshot.

.NOTES
    Name:        Export-Endpoint-Health-Snapshot.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Endpoint health snapshot written
    Exit 1:      Snapshot export failed

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

$ScriptPackageName = 'Export-Endpoint-Health-Snapshot'
$ScriptName = 'Export-Endpoint-Health-Snapshot'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'EndpointHealthSnapshot.json'
$ServicesToReport = @('IntuneManagementExtension', 'wuauserv', 'BITS', 'WinDefend')
$RecentEventMinutes = 120

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

    if (-not (Test-Path -LiteralPath $InventoryRoot -PathType Container)) {
        New-Item -Path $InventoryRoot -ItemType Directory -Force | Out-Null
    }

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $logicalDisks = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue)
    $services = foreach ($serviceName in $ServicesToReport) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        [ordered]@{ Name = $serviceName; Found = ($null -ne $service); Status = if ($service) { [string]$service.Status } else { '' }; StartType = if ($service) { [string]$service.StartType } else { '' } }
    }
    $eventStart = (Get-Date).AddMinutes(-1 * $RecentEventMinutes)
    $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2; StartTime = $eventStart } -ErrorAction SilentlyContinue | Select-Object -First 25 TimeCreated, ProviderName, Id, LevelDisplayName, Message)

    $snapshot = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        UptimeDays = [math]::Round(((Get-Date) - ([System.Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime))).TotalDays, 2)
        LastBootUpTime = ([System.Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)).ToString('yyyy-MM-dd HH:mm:ss')
        FreePhysicalMemoryMB = [math]::Round(([double]$os.FreePhysicalMemory / 1024), 2)
        TotalVisibleMemoryMB = [math]::Round(([double]$os.TotalVisibleMemorySize / 1024), 2)
        Disks = @($logicalDisks | ForEach-Object { [ordered]@{ DeviceId = [string]$_.DeviceID; FreeGB = [math]::Round(([double]$_.FreeSpace / 1GB), 2); SizeGB = [math]::Round(([double]$_.Size / 1GB), 2) } })
        Services = @($services)
        RecentSystemErrors = @($events)
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $snapshot | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    Write-Output "Endpoint health snapshot written to '$inventoryPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export endpoint health snapshot.'
    exit 1
}
