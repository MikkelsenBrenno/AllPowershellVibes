<#
.SYNOPSIS
    Exports Windows Update policy registry state.

.DESCRIPTION
    Intune platform script example. The script reads common Windows Update
    policy registry paths and writes a JSON snapshot for troubleshooting
    update rings, active hours, target release, and update source behavior.

.NOTES
    Name:        Export-Windows-Update-Policy-State.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Windows Update policy snapshot written
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

$ScriptPackageName = 'Export-Windows-Update-Policy-State'
$ScriptName = 'Export-Windows-Update-Policy-State'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'WindowsUpdatePolicyState.json'
$PolicyRegistryPaths = @(
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate',
    'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
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

function Convert-RegistryItemToObject {
    param(
        [string]$Path
    )

    $values = [ordered]@{}
    $item = Get-ItemProperty -LiteralPath $Path -ErrorAction SilentlyContinue

    if ($null -ne $item) {
        foreach ($property in $item.PSObject.Properties) {
            if ($property.Name -notlike 'PS*') {
                $values[$property.Name] = $property.Value
            }
        }
    }

    return [ordered]@{
        Path = $Path
        Exists = ($null -ne $item)
        Values = $values
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

    $policyState = foreach ($path in $PolicyRegistryPaths) {
        Convert-RegistryItemToObject -Path $path
    }

    $snapshot = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        PolicyRegistryPaths = @($policyState)
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    Write-Output "Windows Update policy state written to '$inventoryPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export Windows Update policy state.'
    exit 1
}
