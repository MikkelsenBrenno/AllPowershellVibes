<#
.SYNOPSIS
    Configures Storage Sense policy.

.DESCRIPTION
    Intune Remediations remediation script. The script writes configurable
    machine policy registry values for Storage Sense after ApplyPolicy is
    enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Storage Sense policy matches expected values
    Exit 1:      Storage Sense policy remains missing or different

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

$ScriptPackageName = 'Ensure-Storage-Sense-Policy-Enabled'
$ScriptName = 'Remediate'

$StorageSensePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense'
$EnableValueName = 'AllowStorageSenseGlobal'
$EnableValue = 1
$CadenceValueName = 'ConfigStorageSenseGlobalCadence'
$CadenceValue = 30
$WriteCadenceValue = $true
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
        Write-Output 'Storage Sense policy would be configured, but ApplyPolicy is disabled.'
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    if (-not (Test-Path -LiteralPath $StorageSensePolicyPath -PathType Container)) {
        New-Item -Path $StorageSensePolicyPath -Force | Out-Null
    }

    New-ItemProperty -Path $StorageSensePolicyPath -Name $EnableValueName -Value $EnableValue -PropertyType DWord -Force | Out-Null

    if ($WriteCadenceValue) {
        New-ItemProperty -Path $StorageSensePolicyPath -Name $CadenceValueName -Value $CadenceValue -PropertyType DWord -Force | Out-Null
    }

    $item = Get-ItemProperty -LiteralPath $StorageSensePolicyPath -ErrorAction Stop
    if ([int]$item.$EnableValueName -ne $EnableValue) {
        throw "$EnableValueName was not set to '$EnableValue'."
    }

    if ($WriteCadenceValue -and [int]$item.$CadenceValueName -ne $CadenceValue) {
        throw "$CadenceValueName was not set to '$CadenceValue'."
    }

    Write-Output "Storage Sense policy was configured. Enabled='$EnableValue'; Cadence='$CadenceValue'."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed while configuring Storage Sense policy.'
    exit 1
}
