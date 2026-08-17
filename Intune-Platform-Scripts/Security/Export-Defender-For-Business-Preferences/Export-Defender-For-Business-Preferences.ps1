<#
.SYNOPSIS
    Exports Microsoft Defender local preferences and status.

.DESCRIPTION
    Intune platform script for Microsoft 365 Business Premium environments.
    The script collects local Microsoft Defender preferences and computer
    status values into a JSON file for troubleshooting Defender for Business.

.NOTES
    Name:        Export-Defender-For-Business-Preferences.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Platform Script
    Exit 0:      Defender information exported
    Exit 1:      Defender information export failed

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

$ScriptPackageName = 'Export-Defender-For-Business-Preferences'
$ScriptName = 'Export-Defender-For-Business-Preferences'

$OutputRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$OutputFileName = 'DefenderForBusinessPreferences.json'
$PreferencePropertyNames = @(
    'DisableRealtimeMonitoring',
    'DisableBehaviorMonitoring',
    'PUAProtection',
    'MAPSReporting',
    'SubmitSamplesConsent',
    'CloudBlockLevel',
    'ScanScheduleDay',
    'ScanScheduleTime'
)

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }; if (-not (Test-Path -LiteralPath $OutputRoot)) { New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $preference = if (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue) { Get-MpPreference } else { $null }
    $status = if (Get-Command -Name Get-MpComputerStatus -ErrorAction SilentlyContinue) { Get-MpComputerStatus } else { $null }
    $selectedPreferences = [ordered]@{}

    foreach ($name in $PreferencePropertyNames) {
        $selectedPreferences[$name] = if ($null -ne $preference) { $preference.$name } else { $null }
    }

    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        CapturedAt = (Get-Date).ToString('o')
        PreferenceCommandAvailable = ($null -ne $preference)
        StatusCommandAvailable = ($null -ne $status)
        Preferences = $selectedPreferences
        Status = if ($null -ne $status) { $status | Select-Object AMServiceEnabled, AntispywareEnabled, AntivirusEnabled, BehaviorMonitorEnabled, IoavProtectionEnabled, NISEnabled, OnAccessProtectionEnabled, RealTimeProtectionEnabled, AntivirusSignatureAge, NISSignatureAge, FullScanAge, QuickScanAge } else { $null }
    }

    $outputPath = Join-Path -Path $OutputRoot -ChildPath $OutputFileName
    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outputPath -Encoding UTF8
    Write-Log -Message "Defender preferences exported to '$outputPath'."
    Write-Output "Defender preferences exported to '$outputPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Defender preference export failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Defender preference export failed.'
    exit 1
}
