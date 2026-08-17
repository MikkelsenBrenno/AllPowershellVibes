<#
.SYNOPSIS
    Writes an endpoint health snapshot.

.DESCRIPTION
    Payload script for the Win32 endpoint health tool template. The script
    writes a local JSON snapshot with uptime, disk, memory, and service state.

.NOTES
    Name:        EndpointHealthSnapshot.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Payload
    Exit 0:      Snapshot written
    Exit 1:      Snapshot failed

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

$ScriptPackageName = 'Install-Endpoint-Health-Snapshot-Tool'
$ScriptName = 'EndpointHealthSnapshot'

$SnapshotRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\EndpointHealth'
$SnapshotFileName = 'EndpointHealthSnapshot.json'
$ServicesToReport = @('IntuneManagementExtension', 'wuauserv', 'BITS')

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
    $disk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
    $services = foreach ($serviceName in $ServicesToReport) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        [ordered]@{ Name = $serviceName; Found = ($null -ne $service); Status = if ($service) { [string]$service.Status } else { '' } }
    }

    $snapshot = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        UptimeDays = [math]::Round(((Get-Date) - ([System.Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime))).TotalDays, 2)
        FreeMemoryMB = [math]::Round(([double]$os.FreePhysicalMemory / 1024), 2)
        DiskFreeGB = if ($disk) { [math]::Round(([double]$disk.FreeSpace / 1GB), 2) } else { $null }
        Services = @($services)
    }

    $snapshotPath = Join-Path -Path $SnapshotRoot -ChildPath $SnapshotFileName
    $snapshot | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $snapshotPath -Encoding UTF8

    Write-Output "Endpoint health snapshot written to '$snapshotPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Payload failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Endpoint health snapshot failed.'
    exit 1
}
