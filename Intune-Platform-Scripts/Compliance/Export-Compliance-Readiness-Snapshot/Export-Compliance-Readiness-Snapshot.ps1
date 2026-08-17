<#
.SYNOPSIS
    Exports a local compliance readiness snapshot.

.DESCRIPTION
    Intune platform script example. The script collects common local readiness
    signals used by compliance policies and writes a JSON snapshot.

.NOTES
    Name:        Export-Compliance-Readiness-Snapshot.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Compliance readiness snapshot written
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

$ScriptPackageName = 'Export-Compliance-Readiness-Snapshot'
$ScriptName = 'Export-Compliance-Readiness-Snapshot'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'ComplianceReadinessSnapshot.json'

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

    $secureBoot = $null
    try { $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop } catch {}
    $tpm = Get-CimInstance -Namespace 'root\cimv2\Security\MicrosoftTpm' -ClassName Win32_Tpm -ErrorAction SilentlyContinue
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $defender = if (Get-Command -Name Get-MpComputerStatus -ErrorAction SilentlyContinue) { Get-MpComputerStatus -ErrorAction SilentlyContinue } else { $null }

    $snapshot = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        WindowsCaption = [string]$os.Caption
        WindowsVersion = [string]$os.Version
        WindowsBuild = [string]$os.BuildNumber
        SecureBootEnabled = $secureBoot
        TpmPresent = ($null -ne $tpm)
        TpmEnabled = if ($null -ne $tpm) { [bool]$tpm.IsEnabled_InitialValue } else { $false }
        TpmActivated = if ($null -ne $tpm) { [bool]$tpm.IsActivated_InitialValue } else { $false }
        DefenderStatusAvailable = ($null -ne $defender)
        DefenderRealTimeProtectionEnabled = if ($null -ne $defender) { [bool]$defender.RealTimeProtectionEnabled } else { $false }
        DefenderAntivirusEnabled = if ($null -ne $defender) { [bool]$defender.AntivirusEnabled } else { $false }
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $snapshot | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    Write-Output "Compliance readiness snapshot written to '$inventoryPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export compliance readiness snapshot.'
    exit 1
}
