<#
.SYNOPSIS
    Discovers the active Windows power plan.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks the active
    Windows power plan GUID with powercfg.exe and returns one compressed JSON
    object.

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

$ScriptPackageName = 'Check-Active-Power-Plan'
$ScriptName = 'Discover'

# Built-in examples:
# Balanced: 381b4222-f694-41f0-9685-ff5bb260df2e
# High performance: 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
# Power saver: a1841308-3541-4fab-bc81-f71556f20b4a
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

# =========================
# MAIN
# =========================

$result = [ordered]@{
    ActivePowerPlanCompliant = $false
    ExpectedPowerPlanGuid = $ExpectedPowerPlanGuid
    ActivePowerPlanGuid = ''
    ActivePowerPlanName = ''
    PowerCfgAvailable = $false
}

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Get-Command -Name powercfg.exe -ErrorAction SilentlyContinue)) {
        throw 'powercfg.exe is not available on this device.'
    }

    $result.PowerCfgAvailable = $true
    $powerCfgOutput = (& powercfg.exe /getactivescheme) -join ' '

    if ($powerCfgOutput -match '([0-9a-fA-F-]{36})\s+\((.+)\)') {
        $result.ActivePowerPlanGuid = $matches[1].ToLowerInvariant()
        $result.ActivePowerPlanName = $matches[2]
    }

    $result.ActivePowerPlanCompliant = ($result.ActivePowerPlanGuid -eq $ExpectedPowerPlanGuid.ToLowerInvariant())
    Write-Log -Message "Discovery completed. ActiveGuid='$($result.ActivePowerPlanGuid)'; ExpectedGuid='$ExpectedPowerPlanGuid'; Compliant='$($result.ActivePowerPlanCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.ActivePowerPlanCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
