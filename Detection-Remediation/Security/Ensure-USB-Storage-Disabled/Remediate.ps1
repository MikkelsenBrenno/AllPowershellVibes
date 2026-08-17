<#
.SYNOPSIS
    Disables USB storage.

.DESCRIPTION
    Intune Remediations remediation script. The script writes the USBSTOR
    startup value after ApplyPolicy is enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      USB storage policy matches expected value
    Exit 1:      USB storage policy remains missing or different

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
$ScriptName = 'Remediate'

$UsbStorageRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR'
$StartValueName = 'Start'
$StartValue = 4
$ApplyPolicy = $false
$ExitZeroInReportingOnlyMode = $false

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

    if (-not $ApplyPolicy) {
        Write-Output 'USB storage would be disabled, but ApplyPolicy is disabled.'
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    if (-not (Test-Path -LiteralPath $UsbStorageRegistryPath -PathType Container)) {
        New-Item -Path $UsbStorageRegistryPath -Force | Out-Null
    }

    New-ItemProperty -Path $UsbStorageRegistryPath -Name $StartValueName -Value $StartValue -PropertyType DWord -Force | Out-Null

    $item = Get-ItemProperty -LiteralPath $UsbStorageRegistryPath -Name $StartValueName -ErrorAction Stop
    if ([int]$item.$StartValueName -ne $StartValue) {
        throw "$StartValueName was not set to '$StartValue'."
    }

    Write-Output "USB storage policy was configured. '$StartValueName'='$StartValue'."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed while configuring USB storage policy.'
    exit 1
}
