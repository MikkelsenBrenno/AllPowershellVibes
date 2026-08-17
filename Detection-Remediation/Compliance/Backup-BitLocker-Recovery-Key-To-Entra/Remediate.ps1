<#
.SYNOPSIS
    Attempts to back up BitLocker recovery keys to Entra ID.

.DESCRIPTION
    Intune Remediations remediation script. The script can call
    Backup-BitLockerKeyProtector for RecoveryPassword protectors on the
    configured volume. It is report-only by default.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation completed or report-only mode completed
    Exit 1:      Remediation failed

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

$ScriptPackageName = 'Backup-BitLocker-Recovery-Key-To-Entra'
$ScriptName = 'Remediate'

$MountPoint = 'C:'
$CreateRecoveryPasswordProtectorIfMissing = $false
$ApplyBackupAction = $false

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

    foreach ($commandName in @('Get-BitLockerVolume', 'Backup-BitLockerKeyProtector')) {
        if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
            throw "$commandName is not available on this device."
        }
    }

    $volume = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction Stop
    $recoveryProtectors = @($volume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' })

    if ($recoveryProtectors.Count -eq 0 -and $CreateRecoveryPasswordProtectorIfMissing) {
        if (-not (Get-Command -Name Add-BitLockerKeyProtector -ErrorAction SilentlyContinue)) {
            throw 'Add-BitLockerKeyProtector is required to create a missing recovery password protector.'
        }

        if ($ApplyBackupAction) {
            Add-BitLockerKeyProtector -MountPoint $MountPoint -RecoveryPasswordProtector -ErrorAction Stop | Out-Null
            $volume = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction Stop
            $recoveryProtectors = @($volume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' })
        }
    }

    if (-not $ApplyBackupAction) {
        Write-Output "Report-only mode. Would back up '$($recoveryProtectors.Count)' RecoveryPassword protectors for '$MountPoint'."
        exit 0
    }

    foreach ($protector in $recoveryProtectors) {
        Write-Log -Message "Backing up BitLocker protector '$($protector.KeyProtectorId)' for '$MountPoint'."
        Backup-BitLockerKeyProtector -MountPoint $MountPoint -KeyProtectorId $protector.KeyProtectorId -ErrorAction Stop
    }

    Write-Output 'Remediation completed. BitLocker recovery key backup actions finished.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. BitLocker recovery key backup action did not complete.'
    exit 1
}
