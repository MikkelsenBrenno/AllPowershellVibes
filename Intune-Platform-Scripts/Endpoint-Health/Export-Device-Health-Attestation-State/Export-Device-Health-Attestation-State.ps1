<#
.SYNOPSIS
    Exports local device health attestation signals.

.DESCRIPTION
    Intune platform script for Microsoft 365 Business Premium environments.
    The script collects Secure Boot, TPM, BitLocker, and OS build signals that
    help troubleshoot device health and compliance readiness.

.NOTES
    Name:        Export-Device-Health-Attestation-State.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Platform Script
    Exit 0:      Health attestation signals exported
    Exit 1:      Health attestation signal export failed

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

$ScriptPackageName = 'Export-Device-Health-Attestation-State'
$ScriptName = 'Export-Device-Health-Attestation-State'

$OutputRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$OutputFileName = 'DeviceHealthAttestationState.json'
$SystemDriveMountPoint = 'C:'

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

    $secureBoot = $null
    try { $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop } catch { $secureBoot = $null }

    $tpm = if (Get-Command -Name Get-Tpm -ErrorAction SilentlyContinue) { Get-Tpm } else { $null }
    $bitLocker = if (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue) { Get-BitLockerVolume -MountPoint $SystemDriveMountPoint -ErrorAction SilentlyContinue } else { $null }
    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop

    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        CapturedAt = (Get-Date).ToString('o')
        SecureBootEnabled = $secureBoot
        Tpm = if ($null -ne $tpm) { $tpm | Select-Object TpmPresent, TpmReady, TpmEnabled, TpmActivated, ManufacturerIdTxt, ManufacturerVersion } else { $null }
        BitLocker = if ($null -ne $bitLocker) { $bitLocker | Select-Object MountPoint, VolumeStatus, ProtectionStatus, EncryptionMethod, EncryptionPercentage } else { $null }
        OperatingSystem = $os | Select-Object Caption, Version, BuildNumber, OSArchitecture, LastBootUpTime
    }

    $outputPath = Join-Path -Path $OutputRoot -ChildPath $OutputFileName
    $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outputPath -Encoding UTF8
    Write-Log -Message "Device health attestation signals exported to '$outputPath'."
    Write-Output "Device health attestation signals exported to '$outputPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Device health attestation export failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Device health attestation export failed.'
    exit 1
}
