<#
.SYNOPSIS
    Writes a local inventory snapshot.

.DESCRIPTION
    Payload script for the Win32 inventory collector template. The script
    writes a local JSON snapshot with OS, BIOS, and installed application
    counts for technician troubleshooting.

.NOTES
    Name:        InventoryCollector.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Payload
    Exit 0:      Inventory written
    Exit 1:      Inventory failed

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
$ScriptName = 'InventoryCollector'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'Win32InventoryCollectorSnapshot.json'
$UninstallRegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
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

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Test-Path -LiteralPath $InventoryRoot -PathType Container)) {
        New-Item -Path $InventoryRoot -ItemType Directory -Force | Out-Null
    }

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
    $installedApps = foreach ($path in $UninstallRegistryPaths) {
        if (Test-Path -LiteralPath $path) {
            Get-ChildItem -LiteralPath $path -ErrorAction SilentlyContinue | ForEach-Object {
                $app = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
                if (-not [string]::IsNullOrWhiteSpace($app.DisplayName)) {
                    [string]$app.DisplayName
                }
            }
        }
    }

    $snapshot = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        SerialNumber = [string]$bios.SerialNumber
        WindowsCaption = [string]$os.Caption
        WindowsVersion = [string]$os.Version
        WindowsBuild = [string]$os.BuildNumber
        InstalledApplicationCount = @($installedApps).Count
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $snapshot | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    Write-Output "Inventory snapshot written to '$inventoryPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Payload failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Inventory collection failed.'
    exit 1
}
