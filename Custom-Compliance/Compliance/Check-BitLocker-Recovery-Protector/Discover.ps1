<#
.SYNOPSIS
    Discovers whether a BitLocker recovery protector exists.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks a
    configurable BitLocker volume for recovery password or recovery key
    protectors and returns one compressed JSON object.

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

$ScriptPackageName = 'Check-BitLocker-Recovery-Protector'
$ScriptName = 'Discover'

$MountPoint = 'C:'
$AcceptedRecoveryProtectorTypes = @('RecoveryPassword', 'RecoveryKey')

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log {
    param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO')
    Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8
}
function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

# =========================
# MAIN
# =========================

$result = [ordered]@{
    BitLockerRecoveryProtectorPresent = $false
    BitLockerProtectorCount = 0
    BitLockerRecoveryProtectorTypes = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Discovery started. MountPoint='$MountPoint'."

    if (-not (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
        throw 'Get-BitLockerVolume is not available on this device.'
    }

    $volume = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction Stop
    $protectors = @($volume.KeyProtector)
    $recoveryProtectors = @($protectors | Where-Object { $AcceptedRecoveryProtectorTypes -contains $_.KeyProtectorType.ToString() })
    $recoveryProtectorTypes = @($recoveryProtectors | ForEach-Object { $_.KeyProtectorType.ToString() } | Sort-Object -Unique)

    $result.BitLockerProtectorCount = [int]$protectors.Count
    $result.BitLockerRecoveryProtectorTypes = ($recoveryProtectorTypes -join ',')
    $result.BitLockerRecoveryProtectorPresent = ($recoveryProtectors.Count -gt 0)
    Write-Log -Message "Discovery completed. ProtectorCount='$($result.BitLockerProtectorCount)'; RecoveryProtectorTypes='$($result.BitLockerRecoveryProtectorTypes)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.BitLockerRecoveryProtectorPresent = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
