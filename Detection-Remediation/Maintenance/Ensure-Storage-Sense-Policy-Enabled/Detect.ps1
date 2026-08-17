<#
.SYNOPSIS
    Detects Storage Sense policy state.

.DESCRIPTION
    Intune Remediations detection script. The script checks configurable
    machine policy registry values for Storage Sense.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Storage Sense policy matches expected values
    Exit 1:      Storage Sense policy is missing or different

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
$ScriptName = 'Detect'

$StorageSensePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense'
$EnableValueName = 'AllowStorageSenseGlobal'
$ExpectedEnableValue = 1
$CadenceValueName = 'ConfigStorageSenseGlobalCadence'
$ExpectedCadenceValue = 30
$RequireCadenceValue = $true

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

    if (-not (Test-Path -LiteralPath $StorageSensePolicyPath -PathType Container)) {
        Write-Output "Not compliant. Registry path '$StorageSensePolicyPath' was not found."
        exit 1
    }

    $item = Get-ItemProperty -LiteralPath $StorageSensePolicyPath -ErrorAction Stop
    $actualEnableValue = [int]$item.$EnableValueName

    if ($actualEnableValue -ne $ExpectedEnableValue) {
        Write-Output "Not compliant. Storage Sense enable value is '$actualEnableValue'."
        exit 1
    }

    if ($RequireCadenceValue) {
        $actualCadenceValue = [int]$item.$CadenceValueName
        if ($actualCadenceValue -ne $ExpectedCadenceValue) {
            Write-Output "Not compliant. Storage Sense cadence value is '$actualCadenceValue'."
            exit 1
        }
    }

    Write-Output "Compliant. Storage Sense policy is enabled with cadence '$ExpectedCadenceValue'."
    exit 0
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Storage Sense policy could not be validated.'
    exit 1
}
