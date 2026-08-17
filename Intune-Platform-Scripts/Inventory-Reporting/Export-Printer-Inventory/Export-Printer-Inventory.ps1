<#
.SYNOPSIS
    Exports installed printer inventory to a local JSON file.

.DESCRIPTION
    Intune platform script. The script collects installed printer details using
    Get-Printer when available and falls back to CIM. Results are written to a
    configurable ProgramData path for troubleshooting.

.NOTES
    Name:        Export-Printer-Inventory.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System or user

.INTUNE
    Workload:    Platform Script
    Exit 0:      Inventory exported
    Exit 1:      Inventory export failed

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

$ScriptPackageName = 'Export-Printer-Inventory'
$ScriptName = 'Export-Printer-Inventory'

$OutputRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$OutputFileName = 'PrinterInventory.json'
$IncludeCimFallbackProperties = $true

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }; if (-not (Test-Path -LiteralPath $OutputRoot)) { New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-PrinterInventoryItem {
    if (Get-Command -Name Get-Printer -ErrorAction SilentlyContinue) {
        return @(Get-Printer -ErrorAction Stop | Select-Object Name, DriverName, PortName, Shared, Published, Type, PrinterStatus)
    }

    if ($IncludeCimFallbackProperties) {
        return @(Get-CimInstance -ClassName Win32_Printer -ErrorAction Stop | Select-Object Name, DriverName, PortName, Shared, Network, Default, WorkOffline)
    }

    throw 'Get-Printer is unavailable and CIM fallback is disabled.'
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $outputPath = Join-Path -Path $OutputRoot -ChildPath $OutputFileName
    $printers = @(Get-PrinterInventoryItem)

    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        UserName = $env:USERNAME
        CapturedAt = (Get-Date).ToString('o')
        PrinterCount = $printers.Count
        Printers = $printers
    }

    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outputPath -Encoding UTF8
    Write-Log -Message "Printer inventory exported. Path='$outputPath'; PrinterCount='$($printers.Count)'."
    Write-Output "Printer inventory exported to '$outputPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Printer inventory export failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Printer inventory export failed.'
    exit 1
}
