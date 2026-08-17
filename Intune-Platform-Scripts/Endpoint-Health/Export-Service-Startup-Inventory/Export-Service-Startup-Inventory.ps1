<#
.SYNOPSIS
    Exports Windows service startup inventory to a local JSON file.

.DESCRIPTION
    Intune platform script. The script collects service name, display name,
    state, start mode, account, and path details for troubleshooting endpoint
    health and startup behavior.

.NOTES
    Name:        Export-Service-Startup-Inventory.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

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

$ScriptPackageName = 'Export-Service-Startup-Inventory'
$ScriptName = 'Export-Service-Startup-Inventory'

$OutputRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$OutputFileName = 'ServiceStartupInventory.json'
$IncludeOnlyNonDefaultStartModes = $false
$NonDefaultStartModes = @('Auto', 'Manual', 'Disabled')

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

    $services = @(Get-CimInstance -ClassName Win32_Service -ErrorAction Stop)

    if ($IncludeOnlyNonDefaultStartModes) {
        $services = @($services | Where-Object { $NonDefaultStartModes -contains [string]$_.StartMode })
    }

    $inventory = @($services | Sort-Object Name | Select-Object Name, DisplayName, State, StartMode, StartName, PathName, ServiceType)
    $outputPath = Join-Path -Path $OutputRoot -ChildPath $OutputFileName

    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        CapturedAt = (Get-Date).ToString('o')
        ServiceCount = $inventory.Count
        Services = $inventory
    }

    $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outputPath -Encoding UTF8
    Write-Log -Message "Service startup inventory exported. Path='$outputPath'; Count='$($inventory.Count)'."
    Write-Output "Service startup inventory exported to '$outputPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Service startup inventory export failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Service startup inventory export failed.'
    exit 1
}
