<#
.SYNOPSIS
    Discovers whether BitLocker uses an expected encryption method.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks one drive
    letter and returns a compressed JSON object for a custom compliance rule.

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

$ScriptPackageName = 'Check-BitLocker-Encryption-Method'
$ScriptName = 'Discover'

$MountPoint = 'C:'
$AllowedEncryptionMethods = @('XtsAes128', 'XtsAes256')

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
    EncryptionMethodCompliant = $false
    MountPoint = $MountPoint
    EncryptionMethod = ''
    ProtectionStatus = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Get-Command -Name Get-BitLockerVolume -ErrorAction SilentlyContinue)) {
        throw 'Get-BitLockerVolume is not available on this device.'
    }

    $volume = Get-BitLockerVolume -MountPoint $MountPoint -ErrorAction Stop
    $result.EncryptionMethod = [string]$volume.EncryptionMethod
    $result.ProtectionStatus = [string]$volume.ProtectionStatus
    $result.EncryptionMethodCompliant = ($AllowedEncryptionMethods -contains [string]$volume.EncryptionMethod)

    Write-Log -Message "Discovery completed. MountPoint='$MountPoint'; EncryptionMethod='$($result.EncryptionMethod)'; Allowed='$($AllowedEncryptionMethods -join ',')'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.EncryptionMethodCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
