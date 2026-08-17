<#
.SYNOPSIS
    Exports Wi-Fi profile inventory.

.DESCRIPTION
    Intune platform script example. The script collects Wi-Fi profile names
    from netsh WLAN output and writes a JSON snapshot for technician
    troubleshooting. It does not export wireless keys.

.NOTES
    Name:        Export-WiFi-Profile-Inventory.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Wi-Fi inventory snapshot written
    Exit 1:      Inventory snapshot failed

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

$ScriptPackageName = 'Export-WiFi-Profile-Inventory'
$ScriptName = 'Export-WiFi-Profile-Inventory'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'WiFiProfileInventory.json'
$ExpectedProfileNames = @('Contoso WiFi')

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

    if (-not (Get-Command -Name netsh.exe -ErrorAction SilentlyContinue)) {
        throw 'netsh.exe is not available on this device.'
    }

    $profileOutput = @(netsh.exe wlan show profiles)
    $profiles = @()

    foreach ($line in $profileOutput) {
        if ($line -match ':\s*(.+)$') {
            $profileName = $matches[1].Trim()
            if (-not [string]::IsNullOrWhiteSpace($profileName)) {
                $profiles += $profileName
            }
        }
    }

    $profiles = @($profiles | Sort-Object -Unique)
    $expectedProfileResults = foreach ($expectedProfileName in $ExpectedProfileNames) {
        [ordered]@{
            Name = $expectedProfileName
            Present = ($profiles -contains $expectedProfileName)
        }
    }

    $snapshot = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        ProfileCount = $profiles.Count
        Profiles = @($profiles)
        ExpectedProfiles = @($expectedProfileResults)
        KeysExported = $false
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $snapshot | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    Write-Output "Wi-Fi profile inventory written to '$inventoryPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export Wi-Fi profile inventory.'
    exit 1
}
