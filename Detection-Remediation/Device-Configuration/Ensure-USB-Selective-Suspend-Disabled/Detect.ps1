<#
.SYNOPSIS
    Detects whether USB selective suspend is disabled on the active power plan.

.DESCRIPTION
    Intune Remediations detection script. The script uses powercfg to read the
    active power scheme and checks AC and DC USB selective suspend values.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      USB selective suspend matches the expected values
    Exit 1:      USB selective suspend is enabled or could not be validated

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
$ScriptName = 'Detect'

$PowerCfgPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\powercfg.exe'
$UsbSettingsSubgroupGuid = '2a737441-1930-4402-8d77-b2bebba308a3'
$UsbSelectiveSuspendSettingGuid = '48e6b7a6-50f5-4782-a5d4-53bb8f07e226'
$ExpectedAcValueIndex = 0
$ExpectedDcValueIndex = 0

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

function Get-PowerSettingIndexes {
    param([Parameter(Mandatory = $true)][string]$SchemeGuid)

    $output = @(& $PowerCfgPath /query $SchemeGuid $UsbSettingsSubgroupGuid $UsbSelectiveSuspendSettingGuid 2>&1)
    $joined = $output -join "`n"
    $ac = $null
    $dc = $null

    if ($joined -match 'Current AC Power Setting Index:\s*0x([a-fA-F0-9]+)') {
        $ac = [convert]::ToInt32($matches[1], 16)
    }

    if ($joined -match 'Current DC Power Setting Index:\s*0x([a-fA-F0-9]+)') {
        $dc = [convert]::ToInt32($matches[1], 16)
    }

    if ($null -eq $ac -or $null -eq $dc) {
        throw "Could not parse USB selective suspend values from powercfg output: $joined"
    }

    return [pscustomobject]@{ AC = $ac; DC = $dc }
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
    $indexes = Get-PowerSettingIndexes -SchemeGuid $schemeGuid

    if ($indexes.AC -eq $ExpectedAcValueIndex -and $indexes.DC -eq $ExpectedDcValueIndex) {
        $message = "Compliant. USB selective suspend AC='$($indexes.AC)' DC='$($indexes.DC)' on scheme '$schemeGuid'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. USB selective suspend AC='$($indexes.AC)' DC='$($indexes.DC)' on scheme '$schemeGuid'."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'USB selective suspend could not be validated.'
    exit 1
}
