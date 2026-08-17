<#
.SYNOPSIS
    Exports a Microsoft Defender security snapshot.

.DESCRIPTION
    Intune platform script example. The script collects Microsoft Defender
    status and preference details, then writes a local JSON snapshot.

.NOTES
    Name:        Export-Defender-Security-Snapshot.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Defender snapshot written
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

$ScriptPackageName = 'Export-Defender-Security-Snapshot'
$ScriptName = 'Export-Defender-Security-Snapshot'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'DefenderSecuritySnapshot.json'

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

    if (-not (Get-Command -Name Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
        throw 'Microsoft Defender cmdlets are not available on this device.'
    }

    $status = Get-MpComputerStatus -ErrorAction Stop
    $preference = if (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue) { Get-MpPreference -ErrorAction SilentlyContinue } else { $null }

    $snapshot = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        AntivirusEnabled = [bool]$status.AntivirusEnabled
        RealTimeProtectionEnabled = [bool]$status.RealTimeProtectionEnabled
        BehaviorMonitorEnabled = [bool]$status.BehaviorMonitorEnabled
        IoavProtectionEnabled = [bool]$status.IoavProtectionEnabled
        IsTamperProtected = if ($status.PSObject.Properties.Name -contains 'IsTamperProtected') { [bool]$status.IsTamperProtected } else { $null }
        AntivirusSignatureLastUpdated = [string]$status.AntivirusSignatureLastUpdated
        AntivirusSignatureVersion = [string]$status.AntivirusSignatureVersion
        NISEnabled = [bool]$status.NISEnabled
        NISSignatureLastUpdated = [string]$status.NISSignatureLastUpdated
        PUAProtection = if ($null -ne $preference) { [string]$preference.PUAProtection } else { '' }
        MAPSReporting = if ($null -ne $preference) { [string]$preference.MAPSReporting } else { '' }
        SubmitSamplesConsent = if ($null -ne $preference) { [string]$preference.SubmitSamplesConsent } else { '' }
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $snapshot | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    Write-Output "Defender security snapshot written to '$inventoryPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export Defender security snapshot.'
    exit 1
}
