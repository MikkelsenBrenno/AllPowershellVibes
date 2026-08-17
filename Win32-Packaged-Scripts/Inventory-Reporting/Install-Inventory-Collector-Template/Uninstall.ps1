<#
.SYNOPSIS
    Removes an inventory collector template.

.DESCRIPTION
    Win32 app uninstall script example. The script removes only the configured
    collector payload and version marker.

.NOTES
    Name:        Uninstall.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Inventory collector removed
    Exit 1:      Inventory collector removal failed

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

$ScriptPackageName = 'Install-Inventory-Collector-Template'
$ScriptName = 'Uninstall'

$ToolRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Tools\InventoryCollector'
$ToolFileNames = @('InventoryCollector.ps1', 'tool-version.txt')
$RemoveToolRootWhenEmpty = $true

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

    foreach ($fileName in $ToolFileNames) {
        $path = Join-Path -Path $ToolRoot -ChildPath $fileName
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Remove-Item -LiteralPath $path -Force -ErrorAction Stop
        }
    }

    if ($RemoveToolRootWhenEmpty -and (Test-Path -LiteralPath $ToolRoot -PathType Container)) {
        $remainingItems = @(Get-ChildItem -LiteralPath $ToolRoot -Force -ErrorAction SilentlyContinue)
        if ($remainingItems.Count -eq 0) {
            Remove-Item -LiteralPath $ToolRoot -Force -ErrorAction Stop
        }
    }

    Write-Output 'Uninstall succeeded. Inventory collector is absent.'
    exit 0
}
catch {
    try { Write-Log -Message "Uninstall failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Uninstall failed.'
    exit 1
}
