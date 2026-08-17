<#
.SYNOPSIS
    Exports a local network troubleshooting snapshot.

.DESCRIPTION
    Intune platform script example. The script collects adapter, IP, DNS,
    route, proxy, and connectivity details, then writes a JSON snapshot.

.NOTES
    Name:        Export-Network-Troubleshooting-Snapshot.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Network snapshot written
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

$ScriptPackageName = 'Export-Network-Troubleshooting-Snapshot'
$ScriptName = 'Export-Network-Troubleshooting-Snapshot'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'NetworkTroubleshootingSnapshot.json'
$ConnectivityTargets = @('www.microsoft.com', 'login.microsoftonline.com')

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

    $adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name, InterfaceDescription, Status, LinkSpeed, MacAddress)
    $ipConfig = @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, InterfaceDescription, IPv4Address, IPv6Address, DNSServer, IPv4DefaultGateway)
    $routes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, NextHop, RouteMetric, ifMetric)
    $winHttpProxy = if (Get-Command -Name netsh.exe -ErrorAction SilentlyContinue) { (@(netsh.exe winhttp show proxy) -join ' ').Trim() } else { '' }
    $connectivity = foreach ($target in $ConnectivityTargets) {
        $ping = Test-Connection -ComputerName $target -Count 1 -Quiet -ErrorAction SilentlyContinue
        [ordered]@{ Target = $target; PingSucceeded = [bool]$ping }
    }

    $snapshot = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        Adapters = @($adapters)
        IPConfiguration = @($ipConfig)
        DefaultRoutes = @($routes)
        WinHttpProxy = $winHttpProxy
        Connectivity = @($connectivity)
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    Write-Output "Network troubleshooting snapshot written to '$inventoryPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export network troubleshooting snapshot.'
    exit 1
}
