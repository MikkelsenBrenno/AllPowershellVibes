<#
.SYNOPSIS
    Detects whether the system drive has low free disk space.

.DESCRIPTION
    Intune Remediations detection script. The script checks system drive free
    space and triggers remediation when either percentage or absolute free
    space is below the configured threshold.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Disk free space is above configured thresholds
    Exit 1:      Disk free space is below a configured threshold

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

$ScriptPackageName = 'Run-Disk-Cleanup-When-Low-Free-Space'
$ScriptName = 'Detect'

$DriveLetter = $env:SystemDrive.TrimEnd('\')
$MinimumFreePercent = 15
$MinimumFreeGB = 10

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

    $logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID = '$DriveLetter'" -ErrorAction Stop
    $freeGB = [math]::Round(($logicalDisk.FreeSpace / 1GB), 2)
    $freePercent = [math]::Round((($logicalDisk.FreeSpace / $logicalDisk.Size) * 100), 2)

    if ($freePercent -ge $MinimumFreePercent -and $freeGB -ge $MinimumFreeGB) {
        $message = "Compliant. Drive '$DriveLetter' free space is '$freeGB' GB / '$freePercent' percent."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Drive '$DriveLetter' free space is '$freeGB' GB / '$freePercent' percent."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Disk free space could not be validated.'
    exit 1
}
