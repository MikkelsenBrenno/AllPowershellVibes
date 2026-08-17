<#
.SYNOPSIS
    Exports provisioned AppX package inventory.

.DESCRIPTION
    Intune platform script for Microsoft 365 Business Premium environments.
    The script exports provisioned AppX packages and optional installed AppX
    package counts for troubleshooting built-in app state.

.NOTES
    Name:        Export-Appx-Provisioned-Package-Inventory.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Platform Script
    Exit 0:      AppX inventory exported
    Exit 1:      AppX inventory export failed

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

$ScriptPackageName = 'Export-Appx-Provisioned-Package-Inventory'
$ScriptName = 'Export-Appx-Provisioned-Package-Inventory'

$OutputRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$OutputFileName = 'AppxProvisionedPackageInventory.json'
$IncludeInstalledPackageCounts = $true

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }; if (-not (Test-Path -LiteralPath $OutputRoot)) { New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $provisioned = if (Get-Command -Name Get-AppxProvisionedPackage -ErrorAction SilentlyContinue) { @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | Select-Object DisplayName, PackageName, Version, Architecture, ResourceId) } else { @() }
    $installedCounts = @()

    if ($IncludeInstalledPackageCounts -and (Get-Command -Name Get-AppxPackage -ErrorAction SilentlyContinue)) {
        $installedCounts = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Group-Object Name | Select-Object Name, Count)
    }

    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        CapturedAt = (Get-Date).ToString('o')
        ProvisionedPackageCount = $provisioned.Count
        ProvisionedPackages = $provisioned
        InstalledPackageCounts = $installedCounts
    }

    $outputPath = Join-Path -Path $OutputRoot -ChildPath $OutputFileName
    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outputPath -Encoding UTF8
    Write-Log -Message "AppX inventory exported to '$outputPath'."
    Write-Output "AppX inventory exported to '$outputPath'."
    exit 0
}
catch {
    try { Write-Log -Message "AppX inventory export failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'AppX inventory export failed.'
    exit 1
}
