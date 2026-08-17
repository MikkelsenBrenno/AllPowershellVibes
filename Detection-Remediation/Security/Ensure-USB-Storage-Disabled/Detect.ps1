<#
.SYNOPSIS
    Detects whether USB storage is disabled.

.DESCRIPTION
    Intune Remediations detection script. The script checks the USBSTOR
    service registry startup value and exits 1 when it does not match the
    expected policy value.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      USB storage policy matches expected value
    Exit 1:      USB storage policy is missing or different

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

$ScriptPackageName = 'Ensure-USB-Storage-Disabled'
$ScriptName = 'Detect'

$UsbStorageRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR'
$StartValueName = 'Start'
$ExpectedStartValue = 4

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

    if (-not (Test-Path -LiteralPath $UsbStorageRegistryPath -PathType Container)) {
        Write-Output "Not compliant. Registry path '$UsbStorageRegistryPath' was not found."
        exit 1
    }

    $item = Get-ItemProperty -LiteralPath $UsbStorageRegistryPath -Name $StartValueName -ErrorAction Stop
    $actualStartValue = [int]$item.$StartValueName

    if ($actualStartValue -eq $ExpectedStartValue) {
        Write-Output "Compliant. USB storage start value is '$actualStartValue'."
        exit 0
    }

    Write-Output "Not compliant. USB storage start value is '$actualStartValue'."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. USB storage policy could not be validated.'
    exit 1
}
