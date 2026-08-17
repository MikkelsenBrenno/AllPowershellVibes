<#
.SYNOPSIS
    Refreshes a local troubleshooting snapshot.

.DESCRIPTION
    Intune Remediations remediation script. The script collects common device,
    service, disk, update, and Intune Management Extension details and writes a
    JSON snapshot for technician troubleshooting.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Troubleshooting snapshot refreshed
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

$ScriptPackageName = 'Refresh-Device-Troubleshooting-Snapshot'
$ScriptName = 'Remediate'

$SnapshotRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$SnapshotFileName = 'DeviceTroubleshootingSnapshot.json'
$ServicesToReport = @('IntuneManagementExtension', 'wuauserv', 'BITS', 'WinDefend')
$DiskDriveLetter = 'C'
$RecentEventLogMinutes = 60

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

    if (-not (Test-Path -LiteralPath $SnapshotRoot -PathType Container)) {
        New-Item -Path $SnapshotRoot -ItemType Directory -Force | Out-Null
    }

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($DiskDriveLetter):'" -ErrorAction SilentlyContinue
    $serviceInventory = foreach ($serviceName in $ServicesToReport) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        [ordered]@{
            Name = $serviceName
            Found = ($null -ne $service)
            Status = if ($null -ne $service) { [string]$service.Status } else { '' }
            StartType = if ($null -ne $service) { [string]$service.StartType } else { '' }
        }
    }

    $eventStart = (Get-Date).AddMinutes(-1 * $RecentEventLogMinutes)
    $recentSystemErrors = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 1, 2; StartTime = $eventStart } -ErrorAction SilentlyContinue | Select-Object -First 25 ProviderName, Id, LevelDisplayName, TimeCreated, Message)

    $snapshot = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        SerialNumber = [string]$bios.SerialNumber
        WindowsCaption = [string]$os.Caption
        WindowsVersion = [string]$os.Version
        WindowsBuild = [string]$os.BuildNumber
        LastBootUpTime = ([System.Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)).ToString('yyyy-MM-dd HH:mm:ss')
        DiskDrive = "$($DiskDriveLetter):"
        DiskFreeGB = if ($null -ne $disk) { [math]::Round(([double]$disk.FreeSpace / 1GB), 2) } else { $null }
        DiskTotalGB = if ($null -ne $disk) { [math]::Round(([double]$disk.Size / 1GB), 2) } else { $null }
        Services = @($serviceInventory)
        RecentSystemErrors = @($recentSystemErrors)
    }

    $snapshotPath = Join-Path -Path $SnapshotRoot -ChildPath $SnapshotFileName
    $snapshot | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $snapshotPath -Encoding UTF8

    if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) {
        throw "Snapshot '$snapshotPath' was not created."
    }

    Write-Output "Remediation succeeded. Troubleshooting snapshot written to '$snapshotPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed to refresh troubleshooting snapshot.'
    exit 1
}
