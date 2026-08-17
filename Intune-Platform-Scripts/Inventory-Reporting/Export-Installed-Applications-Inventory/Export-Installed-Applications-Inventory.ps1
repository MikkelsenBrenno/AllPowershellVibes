<#
.SYNOPSIS
    Exports installed applications inventory.

.DESCRIPTION
    Intune platform script example. The script reads common machine-wide
    uninstall registry locations and writes a JSON inventory of installed
    applications to a configurable local path for technician troubleshooting.

.NOTES
    Name:        Export-Installed-Applications-Inventory.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Application inventory written
    Exit 1:      Application inventory failed

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

$ScriptPackageName = 'Export-Installed-Applications-Inventory'
$ScriptName = 'Export-Installed-Applications-Inventory'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'InstalledApplicationsInventory.json'
$IncludeSystemComponents = $false
$IncludeUpdates = $false
$UninstallRegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-InstalledApplicationInventory {
    $seen = @{}

    foreach ($registryPath in $UninstallRegistryPaths) {
        $architecture = if ($registryPath -like '*WOW6432Node*') { '32-bit' } else { '64-bit' }
        $items = @(Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue)

        foreach ($item in $items) {
            $displayName = [string]$item.DisplayName

            if ([string]::IsNullOrWhiteSpace($displayName)) {
                continue
            }

            if (-not $IncludeSystemComponents -and [int]($item.SystemComponent) -eq 1) {
                continue
            }

            $releaseType = [string]$item.ReleaseType
            if (-not $IncludeUpdates -and $releaseType -match 'Update|Hotfix|Security Update') {
                continue
            }

            $key = '{0}|{1}|{2}|{3}' -f $displayName, $item.DisplayVersion, $item.Publisher, $item.PSChildName
            if ($seen.ContainsKey($key)) {
                continue
            }

            $seen[$key] = $true

            [PSCustomObject]@{
                DisplayName = $displayName
                DisplayVersion = [string]$item.DisplayVersion
                Publisher = [string]$item.Publisher
                InstallDate = [string]$item.InstallDate
                RegistryKey = [string]$item.PSChildName
                RegistryArchitecture = $architecture
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

    $applications = @(Get-InstalledApplicationInventory | Sort-Object -Property DisplayName, DisplayVersion, Publisher)
    $inventory = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        ApplicationCount = $applications.Count
        IncludeSystemComponents = [bool]$IncludeSystemComponents
        IncludeUpdates = [bool]$IncludeUpdates
        Applications = $applications
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $inventory | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) {
        throw "Installed applications inventory '$inventoryPath' was not created."
    }

    Write-Log -Message "Application inventory written. Path='$inventoryPath'; Count='$($applications.Count)'."
    Write-Output "Installed applications inventory written to '$inventoryPath'. ApplicationCount='$($applications.Count)'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export installed applications inventory.'
    exit 1
}
