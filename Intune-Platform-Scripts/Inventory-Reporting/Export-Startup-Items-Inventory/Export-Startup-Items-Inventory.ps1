<#
.SYNOPSIS
    Exports startup items inventory.

.DESCRIPTION
    Intune platform script example. The script collects machine-wide startup
    registry entries and Startup folder items, then writes a JSON inventory
    file to a configurable local path for technician troubleshooting.

.NOTES
    Name:        Export-Startup-Items-Inventory.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Startup items inventory written
    Exit 1:      Startup items inventory failed

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

$ScriptPackageName = 'Export-Startup-Items-Inventory'
$ScriptName = 'Export-Startup-Items-Inventory'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'StartupItemsInventory.json'
$StartupRegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
)
$StartupFolderPaths = @(
    'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup'
)
$PropertyNamesToIgnore = @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-StartupRegistryItem {
    foreach ($registryPath in $StartupRegistryPaths) {
        if (-not (Test-Path -LiteralPath $registryPath -PathType Container)) {
            continue
        }

        $item = Get-ItemProperty -LiteralPath $registryPath -ErrorAction SilentlyContinue
        if ($null -eq $item) {
            continue
        }

        foreach ($property in $item.PSObject.Properties) {
            if ($PropertyNamesToIgnore -contains $property.Name) {
                continue
            }

            [PSCustomObject]@{
                Name = [string]$property.Name
                Command = [string]$property.Value
                SourceType = 'Registry'
                SourcePath = $registryPath
                Architecture = if ($registryPath -like '*WOW6432Node*') { '32-bit' } else { '64-bit' }
            }
        }
    }
}

function Get-StartupFolderItem {
    foreach ($folderPath in $StartupFolderPaths) {
        if (-not (Test-Path -LiteralPath $folderPath -PathType Container)) {
            continue
        }

        Get-ChildItem -LiteralPath $folderPath -File -Force -ErrorAction SilentlyContinue |
            Sort-Object -Property Name |
            ForEach-Object {
                [PSCustomObject]@{
                    Name = [string]$_.Name
                    Command = [string]$_.FullName
                    SourceType = 'StartupFolder'
                    SourcePath = $folderPath
                    Architecture = 'AllUsers'
                }
            }
    }
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

    $registryItems = @(Get-StartupRegistryItem)
    $folderItems = @(Get-StartupFolderItem)
    $allItems = @($registryItems + $folderItems | Sort-Object -Property SourceType, Name, SourcePath)

    $inventory = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        StartupItemCount = $allItems.Count
        RegistryItemCount = $registryItems.Count
        StartupFolderItemCount = $folderItems.Count
        StartupItems = $allItems
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $inventory | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) {
        throw "Startup items inventory '$inventoryPath' was not created."
    }

    Write-Log -Message "Startup items inventory written. Path='$inventoryPath'; Count='$($allItems.Count)'."
    Write-Output "Startup items inventory written to '$inventoryPath'. StartupItemCount='$($allItems.Count)'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export startup items inventory.'
    exit 1
}
