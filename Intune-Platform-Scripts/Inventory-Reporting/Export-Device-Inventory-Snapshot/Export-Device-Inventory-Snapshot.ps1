<#
.SYNOPSIS
    Exports a local device inventory snapshot.

.DESCRIPTION
    Intune platform script example. The script collects common device
    inventory details and writes a JSON snapshot to a configurable local path
    for technician troubleshooting.

.NOTES
    Name:        Export-Device-Inventory-Snapshot.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Inventory snapshot written
    Exit 1:      Inventory snapshot failed

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

$ScriptPackageName = 'Export-Device-Inventory-Snapshot'
$ScriptName = 'Export-Device-Inventory-Snapshot'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'DeviceInventorySnapshot.json'
$SystemDriveLetter = 'C'

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

    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$($SystemDriveLetter):'" -ErrorAction SilentlyContinue
    $tpm = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction SilentlyContinue
    $systemDriveFreeGB = $null
    $systemDriveTotalGB = $null
    $tpmReady = $false

    if ($null -ne $logicalDisk) {
        $systemDriveFreeGB = [math]::Round(([double]$logicalDisk.FreeSpace / 1GB), 2)
        $systemDriveTotalGB = [math]::Round(([double]$logicalDisk.Size / 1GB), 2)
    }

    if ($null -ne $tpm) {
        $tpmReady = [bool]$tpm.IsEnabled_InitialValue
    }

    $snapshot = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        Manufacturer = [string]$computerSystem.Manufacturer
        Model = [string]$computerSystem.Model
        SerialNumber = [string]$bios.SerialNumber
        BiosVersion = ($bios.SMBIOSBIOSVersion -join ', ')
        WindowsCaption = [string]$os.Caption
        WindowsVersion = [string]$os.Version
        WindowsBuild = [string]$os.BuildNumber
        LastBootUpTime = ([System.Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)).ToString('yyyy-MM-dd HH:mm:ss')
        SystemDrive = "$($SystemDriveLetter):"
        SystemDriveFreeGB = $systemDriveFreeGB
        SystemDriveTotalGB = $systemDriveTotalGB
        TpmPresent = ($null -ne $tpm)
        TpmReady = $tpmReady
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $snapshot | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) {
        throw "Inventory snapshot '$inventoryPath' was not created."
    }

    Write-Output "Device inventory snapshot written to '$inventoryPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export device inventory snapshot.'
    exit 1
}
