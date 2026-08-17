<#
.SYNOPSIS
    Exports local BitLocker inventory to JSON.

.DESCRIPTION
    Intune platform script example. The script collects BitLocker volume
    status, protection state, encryption status, and key protector types, then
    writes a JSON snapshot to a configurable local path for technician
    troubleshooting.

.NOTES
    Name:        Export-BitLocker-Inventory.ps1
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

$ScriptPackageName = 'Export-BitLocker-Inventory'
$ScriptName = 'Export-BitLocker-Inventory'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'BitLockerInventory.json'

# Leave empty to inventory every BitLocker volume, or specify values like @('C:', 'D:').
$MountPoints = @()

# Key protector types are useful for troubleshooting. IDs are disabled by default.
$IncludeKeyProtectorIds = $false

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

function Convert-KeyProtectorInventory {
    param(
        [AllowNull()]
        [object[]]$KeyProtector,

        [bool]$IncludeIds
    )

    $protectorInventory = @()

    foreach ($protector in @($KeyProtector)) {
        if ($null -eq $protector) {
            continue
        }

        if ($IncludeIds) {
            $protectorInventory += [ordered]@{
                KeyProtectorType = [string]$protector.KeyProtectorType
                KeyProtectorId   = [string]$protector.KeyProtectorId
            }
        }
        else {
            $protectorInventory += [string]$protector.KeyProtectorType
        }
    }

    return @($protectorInventory)
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Inventory started. InventoryRoot='$InventoryRoot'; InventoryFileName='$InventoryFileName'; MountPoints='$($MountPoints -join ',')'."

    if (-not (Test-Path -LiteralPath $InventoryRoot -PathType Container)) {
        New-Item -Path $InventoryRoot -ItemType Directory -Force | Out-Null
    }

    $bitLockerCmdletAvailable = [bool](Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue)
    $volumeInventory = @()

    if ($bitLockerCmdletAvailable) {
        if ($MountPoints.Count -gt 0) {
            foreach ($mountPoint in $MountPoints) {
                Write-Log -Message "Collecting BitLocker volume '$mountPoint'."
                $volume = Get-BitLockerVolume -MountPoint $mountPoint -ErrorAction SilentlyContinue

                if ($null -ne $volume) {
                    $volumeInventory += $volume
                }
            }
        }
        else {
            Write-Log -Message 'Collecting all BitLocker volumes.'
            $volumeInventory = @(Get-BitLockerVolume)
        }
    }
    else {
        Write-Log -Message 'Get-BitLockerVolume is not available on this device.' -Level 'WARN'
    }

    $volumes = @()

    foreach ($volume in @($volumeInventory)) {
        $keyProtectors = Convert-KeyProtectorInventory -KeyProtector $volume.KeyProtector -IncludeIds $IncludeKeyProtectorIds
        $protectorTypes = @($volume.KeyProtector | ForEach-Object { [string]$_.KeyProtectorType })

        $volumes += [ordered]@{
            MountPoint               = [string]$volume.MountPoint
            VolumeType               = [string]$volume.VolumeType
            CapacityGB               = [math]::Round(([double]$volume.CapacityGB), 2)
            VolumeStatus             = [string]$volume.VolumeStatus
            ProtectionStatus         = [string]$volume.ProtectionStatus
            EncryptionPercentage     = [int]$volume.EncryptionPercentage
            EncryptionMethod         = [string]$volume.EncryptionMethod
            LockStatus               = [string]$volume.LockStatus
            AutoUnlockEnabled        = [bool]$volume.AutoUnlockEnabled
            KeyProtectorCount        = @($volume.KeyProtector).Count
            RecoveryProtectorPresent = ($protectorTypes -contains 'RecoveryPassword')
            KeyProtectors            = $keyProtectors
        }
    }

    $snapshot = [ordered]@{
        CapturedAt                 = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName               = $env:COMPUTERNAME
        BitLockerCmdletAvailable   = $bitLockerCmdletAvailable
        RequestedMountPoints       = @($MountPoints)
        IncludeKeyProtectorIds     = $IncludeKeyProtectorIds
        VolumeCount                = @($volumes).Count
        ProtectedVolumeCount       = @($volumes | Where-Object { $_.ProtectionStatus -eq 'On' }).Count
        FullyEncryptedVolumeCount  = @($volumes | Where-Object { $_.VolumeStatus -eq 'FullyEncrypted' }).Count
        RecoveryProtectorVolumeCount = @($volumes | Where-Object { $_.RecoveryProtectorPresent }).Count
        Volumes                    = @($volumes)
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) {
        throw "Inventory snapshot '$inventoryPath' was not created."
    }

    Write-Output "BitLocker inventory snapshot written to '$inventoryPath'."
    exit 0
}
catch {
    try {
        Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Failed to export BitLocker inventory snapshot.'
    exit 1
}
