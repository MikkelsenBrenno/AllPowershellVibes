<#
.SYNOPSIS
    Discovers BitLocker protection state for custom compliance.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks BitLocker
    state for a configurable volume and returns a compressed JSON object.
    Avoid adding normal Write-Output statements because Intune evaluates
    STDOUT as JSON.

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

# Keep these names aligned with the folder and script file.
# Logs are written to Logs\<ScriptPackageName>\<ScriptName>.log.
$ScriptPackageName = 'Example-Check-BitLocker-Status'
$ScriptName = 'Discover'

# Change this to the volume you want to evaluate.
$MountPoint = 'C:'

# Typical compliant value is On.
$RequiredProtectionStatus = 'On'

# Set lower than 100 only if your policy allows partially encrypted volumes.
$MinimumEncryptionPercentage = 100

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

# =========================
# MAIN
# =========================

$result = [ordered]@{
    BitLockerProtected = $false
    BitLockerProtectionStatus = 'Unknown'
    BitLockerEncryptionPercentage = 0
}

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Discovery started. MountPoint='$MountPoint'."

    if (-not (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
        throw 'Get-BitLockerVolume is not available on this device.'
    }

    $volume = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction Stop

    $protectionStatus = $volume.ProtectionStatus.ToString()
    $encryptionPercentage = [int]$volume.EncryptionPercentage

    $result.BitLockerProtectionStatus = $protectionStatus
    $result.BitLockerEncryptionPercentage = $encryptionPercentage
    $result.BitLockerProtected = (
        $protectionStatus -eq $RequiredProtectionStatus -and
        $encryptionPercentage -ge $MinimumEncryptionPercentage
    )

    Write-Log -Message "Discovery completed. ProtectionStatus='$protectionStatus'; EncryptionPercentage='$encryptionPercentage'."
}
catch {
    try {
        Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    $result.BitLockerProtected = $false
    $result.BitLockerProtectionStatus = 'Error'
    $result.BitLockerEncryptionPercentage = 0
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0

