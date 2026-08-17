<#
.SYNOPSIS
    Exports network adapter inventory.

.DESCRIPTION
    Intune platform script example. The script collects physical network
    adapter and IP configuration details, then writes a JSON inventory file to
    a configurable local path for technician troubleshooting.

.NOTES
    Name:        Export-Network-Adapter-Inventory.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Network adapter inventory written
    Exit 1:      Network adapter inventory failed

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

$ScriptPackageName = 'Export-Network-Adapter-Inventory'
$ScriptName = 'Export-Network-Adapter-Inventory'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'NetworkAdapterInventory.json'
$IncludeDisconnectedAdapters = $false
$IncludeNonPhysicalAdapters = $false

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function ConvertTo-StringArray {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return @()
    }

    return @($Value | ForEach-Object { [string]$_ })
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

    $configurations = @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue)
    $configurationByIndex = @{}
    foreach ($configuration in $configurations) {
        $configurationByIndex[[int]$configuration.Index] = $configuration
    }

    $adapters = @(Get-CimInstance -ClassName Win32_NetworkAdapter -ErrorAction Stop |
        Where-Object { $IncludeNonPhysicalAdapters -or [bool]$_.PhysicalAdapter })

    $inventoryAdapters = foreach ($adapter in $adapters) {
        $configuration = $configurationByIndex[[int]$adapter.Index]
        $ipEnabled = ($null -ne $configuration -and [bool]$configuration.IPEnabled)

        if (-not $IncludeDisconnectedAdapters -and -not $ipEnabled) {
            continue
        }

        $speedMbps = $null
        if ($null -ne $adapter.Speed) {
            $speedMbps = [int][math]::Round(([double]$adapter.Speed / 1000000), 0)
        }

        [PSCustomObject]@{
            Name = [string]$adapter.Name
            NetConnectionId = [string]$adapter.NetConnectionID
            Manufacturer = [string]$adapter.Manufacturer
            AdapterType = [string]$adapter.AdapterType
            MacAddress = [string]$adapter.MACAddress
            PhysicalAdapter = [bool]$adapter.PhysicalAdapter
            NetConnectionStatus = [int]$adapter.NetConnectionStatus
            SpeedMbps = $speedMbps
            IpEnabled = [bool]$ipEnabled
            DhcpEnabled = if ($null -ne $configuration) { [bool]$configuration.DHCPEnabled } else { $false }
            IpAddresses = if ($null -ne $configuration) { ConvertTo-StringArray -Value $configuration.IPAddress } else { @() }
            DefaultGateways = if ($null -ne $configuration) { ConvertTo-StringArray -Value $configuration.DefaultIPGateway } else { @() }
            DnsServers = if ($null -ne $configuration) { ConvertTo-StringArray -Value $configuration.DNSServerSearchOrder } else { @() }
        }
    }

    $inventory = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        IncludeDisconnectedAdapters = [bool]$IncludeDisconnectedAdapters
        IncludeNonPhysicalAdapters = [bool]$IncludeNonPhysicalAdapters
        AdapterCount = @($inventoryAdapters).Count
        Adapters = @($inventoryAdapters | Sort-Object -Property Name, NetConnectionId)
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $inventory | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) {
        throw "Network adapter inventory '$inventoryPath' was not created."
    }

    Write-Log -Message "Network adapter inventory written. Path='$inventoryPath'; Count='$($inventory.AdapterCount)'."
    Write-Output "Network adapter inventory written to '$inventoryPath'. AdapterCount='$($inventory.AdapterCount)'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export network adapter inventory.'
    exit 1
}
