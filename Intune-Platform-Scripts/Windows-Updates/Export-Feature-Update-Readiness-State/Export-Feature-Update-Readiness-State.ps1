<#
.SYNOPSIS
    Exports local Windows feature update readiness signals.

.DESCRIPTION
    Intune platform script for Microsoft 365 Business Premium environments.
    The script collects OS build, Windows Update policy, free disk space, TPM,
    Secure Boot, and pending reboot signals for feature update readiness.

.NOTES
    Name:        Export-Feature-Update-Readiness-State.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Platform Script
    Exit 0:      Feature update readiness state exported
    Exit 1:      Feature update readiness export failed

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

$ScriptPackageName = 'Export-Feature-Update-Readiness-State'
$ScriptName = 'Export-Feature-Update-Readiness-State'

$OutputRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$OutputFileName = 'FeatureUpdateReadinessState.json'
$WindowsUpdatePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$CurrentVersionRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$PendingRebootPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
)

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

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $systemDrive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID = '$($env:SystemDrive.TrimEnd('\'))'" -ErrorAction SilentlyContinue
    $currentVersion = if (Test-Path -LiteralPath $CurrentVersionRegistryPath) { Get-ItemProperty -LiteralPath $CurrentVersionRegistryPath -ErrorAction SilentlyContinue } else { $null }
    $wuPolicy = if (Test-Path -LiteralPath $WindowsUpdatePolicyPath) { Get-ItemProperty -LiteralPath $WindowsUpdatePolicyPath -ErrorAction SilentlyContinue } else { $null }
    $pendingRebootSignals = @($PendingRebootPaths | Where-Object { Test-Path -LiteralPath $_ })
    $secureBoot = $null
    try { $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop } catch { $secureBoot = $null }
    $tpm = if (Get-Command -Name Get-Tpm -ErrorAction SilentlyContinue) { Get-Tpm } else { $null }

    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        CapturedAt = (Get-Date).ToString('o')
        OS = $os | Select-Object Caption, Version, BuildNumber, OSArchitecture
        CurrentVersion = if ($null -ne $currentVersion) { $currentVersion | Select-Object ProductName, DisplayVersion, ReleaseId, UBR, EditionID } else { $null }
        SystemDriveFreeGB = if ($null -ne $systemDrive) { [math]::Round(($systemDrive.FreeSpace / 1GB), 2) } else { $null }
        SecureBootEnabled = $secureBoot
        Tpm = if ($null -ne $tpm) { $tpm | Select-Object TpmPresent, TpmReady, TpmEnabled, TpmActivated } else { $null }
        WindowsUpdatePolicy = if ($null -ne $wuPolicy) { $wuPolicy | Select-Object TargetReleaseVersion, TargetReleaseVersionInfo, ProductVersion, DisableWUfBSafeguards, DeferFeatureUpdatesPeriodInDays } else { $null }
        PendingRebootSignals = $pendingRebootSignals
    }

    $outputPath = Join-Path -Path $OutputRoot -ChildPath $OutputFileName
    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outputPath -Encoding UTF8
    Write-Log -Message "Feature update readiness state exported to '$outputPath'."
    Write-Output "Feature update readiness state exported to '$outputPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Feature update readiness export failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Feature update readiness export failed.'
    exit 1
}
