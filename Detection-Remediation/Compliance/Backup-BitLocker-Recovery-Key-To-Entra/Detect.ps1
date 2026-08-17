<#
.SYNOPSIS
    Detects whether BitLocker recovery key backup appears recent.

.DESCRIPTION
    Intune Remediations detection script. The script checks BitLocker recovery
    password protectors and optionally looks for a recent BitLocker Management
    event that indicates key backup activity.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Recovery protector exists and backup signal is acceptable
    Exit 1:      Recovery protector or backup signal is missing

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
$ScriptName = 'Detect'

$MountPoint = 'C:'
$RequireRecentBackupEvent = $false
$BackupEventLogName = 'Microsoft-Windows-BitLocker/BitLocker Management'
$BackupEventId = 845
$MaximumBackupEventAgeDays = 30

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

    if (-not (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
        throw 'Get-BitLockerVolume is not available on this device.'
    }

    $volume = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction Stop
    $recoveryProtectors = @($volume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' })

    if ($recoveryProtectors.Count -eq 0) {
        Write-Output "Not compliant. No RecoveryPassword protector was found on '$MountPoint'."
        exit 1
    }

    if ($RequireRecentBackupEvent) {
        $startTime = (Get-Date).AddDays(-1 * $MaximumBackupEventAgeDays)
        $event = Get-WinEvent -FilterHashtable @{ LogName = $BackupEventLogName; Id = $BackupEventId; StartTime = $startTime } -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($null -eq $event) {
            Write-Output "Not compliant. No recent BitLocker backup event '$BackupEventId' was found within '$MaximumBackupEventAgeDays' days."
            exit 1
        }
    }

    $message = "Compliant. RecoveryPassword protector count='$($recoveryProtectors.Count)' on '$MountPoint'."
    Write-Log -Message $message
    Write-Output $message
    exit 0
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'BitLocker recovery key backup state could not be validated.'
    exit 1
}
