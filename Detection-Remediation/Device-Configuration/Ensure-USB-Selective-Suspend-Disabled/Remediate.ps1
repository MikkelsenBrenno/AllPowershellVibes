<#
.SYNOPSIS
    Disables USB selective suspend on the active power plan.

.DESCRIPTION
    Intune Remediations remediation script. The script can set AC and DC USB
    selective suspend values on the active power scheme. It is report-only by
    default so power plan impact can be piloted first.

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

$ScriptPackageName = 'Ensure-USB-Selective-Suspend-Disabled'
$ScriptName = 'Remediate'

$PowerCfgPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\powercfg.exe'
$UsbSettingsSubgroupGuid = '2a737441-1930-4402-8d77-b2bebba308a3'
$UsbSelectiveSuspendSettingGuid = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
$TargetAcValueIndex = 0
$TargetDcValueIndex = 0
$ApplyPowerCfgChange = $false

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-ActivePowerSchemeGuid {
    $output = @(& $PowerCfgPath /getactivescheme 2>&1) -join ' '
    if ($output -match '([a-fA-F0-9-]{36})') {
        return $matches[1]
    }

    throw "Could not parse active power scheme from powercfg output: $output"
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Test-Path -LiteralPath $PowerCfgPath -PathType Leaf)) {
        throw "powercfg.exe was not found at '$PowerCfgPath'."
    }

    $schemeGuid = Get-ActivePowerSchemeGuid
    Write-Log -Message "Remediation started. Scheme='$schemeGuid'; ApplyPowerCfgChange='$ApplyPowerCfgChange'."

    if (-not $ApplyPowerCfgChange) {
        Write-Output "Report-only mode. Would set USB selective suspend AC='$TargetAcValueIndex' DC='$TargetDcValueIndex' on scheme '$schemeGuid'."
        exit 0
    }

    & $PowerCfgPath /setacvalueindex $schemeGuid $UsbSettingsSubgroupGuid $UsbSelectiveSuspendSettingGuid $TargetAcValueIndex
    if ($LASTEXITCODE -ne 0) { throw "powercfg setacvalueindex failed with exit code '$LASTEXITCODE'." }

    & $PowerCfgPath /setdcvalueindex $schemeGuid $UsbSettingsSubgroupGuid $UsbSelectiveSuspendSettingGuid $TargetDcValueIndex
    if ($LASTEXITCODE -ne 0) { throw "powercfg setdcvalueindex failed with exit code '$LASTEXITCODE'." }

    & $PowerCfgPath /setactive $schemeGuid
    if ($LASTEXITCODE -ne 0) { throw "powercfg setactive failed with exit code '$LASTEXITCODE'." }

    Write-Output "Remediation completed. USB selective suspend was updated on scheme '$schemeGuid'."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. USB selective suspend was not changed.'
    exit 1
}
