<#
.SYNOPSIS
    Exports a Microsoft Teams cache snapshot.

.DESCRIPTION
    Intune platform script example. The script reports configured Teams cache
    folders, their existence, file count, and approximate size. It does not
    delete cache content.

.NOTES
    Name:        Export-Teams-Cache-Snapshot.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     User recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Teams cache snapshot written
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

$ScriptPackageName = 'Export-Teams-Cache-Snapshot'
$ScriptName = 'Export-Teams-Cache-Snapshot'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = "TeamsCacheSnapshot-$($env:USERNAME).json"
$TeamsCacheFolders = @(
    (Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Packages\MSTeams_8wekyb3d8bbwe\LocalCache'),
    (Join-Path -Path $env:APPDATA -ChildPath 'Microsoft\Teams')
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

function Get-FolderSnapshot {
    param([string]$Path)

    $exists = Test-Path -LiteralPath $Path -PathType Container
    $fileCount = 0
    $sizeMB = 0

    if ($exists) {
        $files = @(Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction SilentlyContinue)
        $fileCount = $files.Count
        $sizeMB = [math]::Round((($files | Measure-Object -Property Length -Sum).Sum / 1MB), 2)
    }

    return [ordered]@{
        Path = $Path
        Exists = $exists
        FileCount = $fileCount
        SizeMB = $sizeMB
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

    $folderSnapshots = foreach ($folder in $TeamsCacheFolders) {
        Get-FolderSnapshot -Path $folder
    }

    $snapshot = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        CacheDeleted = $false
        Folders = @($folderSnapshots)
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $snapshot | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    Write-Output "Teams cache snapshot written to '$inventoryPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export Teams cache snapshot.'
    exit 1
}
