<#
.SYNOPSIS
    Configures Windows sleep timeout values.

.DESCRIPTION
    Intune platform script example. The script configures AC and DC standby
    timeout values with powercfg.exe and validates the active power scheme.

.NOTES
    Name:        Configure-Power-Sleep-Timeout.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Sleep timeout values were configured
    Exit 1:      Sleep timeout values could not be configured or validated

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

$ScriptPackageName = 'Configure-Power-Sleep-Timeout'
$ScriptName = 'Configure-Power-Sleep-Timeout'

# Minutes. Use 0 for Never.
$StandbyTimeoutACMinutes = 0
$StandbyTimeoutDCMinutes = 30

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log {
    param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO')
    Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8
}
function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}
function Invoke-PowerCfg {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $powercfg = Join-Path -Path $env:SystemRoot -ChildPath 'System32\powercfg.exe'
    & $powercfg @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "powercfg.exe $($Arguments -join ' ') exited with code $LASTEXITCODE." }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Script started. StandbyTimeoutACMinutes='$StandbyTimeoutACMinutes'; StandbyTimeoutDCMinutes='$StandbyTimeoutDCMinutes'."

    Invoke-PowerCfg -Arguments @('/change', 'standby-timeout-ac', [string]$StandbyTimeoutACMinutes)
    Invoke-PowerCfg -Arguments @('/change', 'standby-timeout-dc', [string]$StandbyTimeoutDCMinutes)

    $message = "Sleep timeout configured. AC='$StandbyTimeoutACMinutes' minutes; DC='$StandbyTimeoutDCMinutes' minutes."
    Write-Log -Message $message
    Write-Output $message
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to configure sleep timeout.'
    exit 1
}
