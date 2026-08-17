<#
.SYNOPSIS
    Discovers BitLocker protection state.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks BitLocker
    protection state for selected fixed drives and returns one compressed JSON
    object for compliance evaluation.

.NOTES
    Name:        Discover.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Custom Compliance
    Output:      Compressed JSON

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

$ScriptPackageName = 'Check-BitLocker-Protection-State'
$ScriptName = 'Discover'

$MountPoints = @('C:')
$ExpectedProtectionStatus = 'On'
$ExpectedVolumeStatus = 'FullyEncrypted'

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

$result = [ordered]@{
    BitLockerProtectionCompliant = $false
    BitLockerCmdletAvailable = $false
    NonCompliantMountPoints = @()
    Volumes = @()
}

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
        throw 'Get-BitLockerVolume is not available.'
    }

    $result.BitLockerCmdletAvailable = $true
    $volumeResults = foreach ($mountPoint in $MountPoints) {
        $volume = Get-BitLockerVolume -MountPoint $mountPoint -ErrorAction Stop
        $protectionStatus = [string]$volume.ProtectionStatus
        $volumeStatus = [string]$volume.VolumeStatus
        $isCompliant = ($protectionStatus -eq $ExpectedProtectionStatus -and $volumeStatus -eq $ExpectedVolumeStatus)

        if (-not $isCompliant) {
            $result.NonCompliantMountPoints += [string]$mountPoint
        }

        [PSCustomObject]@{
            MountPoint = [string]$volume.MountPoint
            ProtectionStatus = $protectionStatus
            VolumeStatus = $volumeStatus
            EncryptionPercentage = [int]$volume.EncryptionPercentage
            Compliant = [bool]$isCompliant
        }
    }

    $result.Volumes = @($volumeResults)
    $result.BitLockerProtectionCompliant = ($result.NonCompliantMountPoints.Count -eq 0)

    Write-Log -Message "Discovery completed. NonCompliantMountPoints='$($result.NonCompliantMountPoints -join ',')'; Compliant='$($result.BitLockerProtectionCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.BitLockerProtectionCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
