<#
.SYNOPSIS
    Detects the active Windows power plan.

.DESCRIPTION
    Intune Remediations detection script. The script checks the active Windows
    power plan GUID and exits 0 when it matches the expected value.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Active power plan matches
    Exit 1:      Active power plan is missing or different

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

$ScriptPackageName = 'Ensure-Active-Power-Plan'
$ScriptName = 'Detect'

$ExpectedPowerPlanGuid = '381b4222-f694-41f0-9685-ff5bb260df2e'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-ActivePowerPlanGuid {
    $output = (& powercfg.exe /getactivescheme) -join ' '
    if ($output -match '([0-9a-fA-F-]{36})') {
        return $matches[1].ToLowerInvariant()
    }

    return ''
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Get-Command -Name powercfg.exe -ErrorAction SilentlyContinue)) {
        throw 'powercfg.exe is not available on this device.'
    }

    $activeGuid = Get-ActivePowerPlanGuid
    Write-Log -Message "ActivePowerPlanGuid='$activeGuid'; ExpectedPowerPlanGuid='$ExpectedPowerPlanGuid'."

    if ($activeGuid -eq $ExpectedPowerPlanGuid.ToLowerInvariant()) {
        Write-Output "Compliant. Active power plan is '$activeGuid'."
        exit 0
    }

    Write-Output "Not compliant. Active power plan is '$activeGuid'."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Active power plan could not be validated.'
    exit 1
}
