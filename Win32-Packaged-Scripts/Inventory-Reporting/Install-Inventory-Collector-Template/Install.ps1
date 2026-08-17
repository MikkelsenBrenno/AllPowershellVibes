<#
.SYNOPSIS
    Installs an inventory collector template.

.DESCRIPTION
    Win32 app install script example. The script copies a local inventory
    collector payload script to ProgramData and writes a version marker.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Inventory collector installed
    Exit 1:      Inventory collector install failed

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
$ScriptName = 'Install'

$ToolRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Tools\InventoryCollector'
$ToolFileName = 'InventoryCollector.ps1'
$PackageVersion = '1.0.0'
$MarkerFileName = 'tool-version.txt'

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

    if (-not (Test-Path -LiteralPath $ToolRoot -PathType Container)) {
        New-Item -Path $ToolRoot -ItemType Directory -Force | Out-Null
    }

    $sourcePath = Join-Path -Path $PSScriptRoot -ChildPath $ToolFileName
    $destinationPath = Join-Path -Path $ToolRoot -ChildPath $ToolFileName

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Tool file '$sourcePath' was not found."
    }

    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
    Set-Content -LiteralPath (Join-Path -Path $ToolRoot -ChildPath $MarkerFileName) -Value $PackageVersion -Encoding ASCII -Force

    Write-Output "Install succeeded. Inventory collector version '$PackageVersion' installed to '$ToolRoot'."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
