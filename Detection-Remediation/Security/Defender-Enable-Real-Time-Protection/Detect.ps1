<#
.SYNOPSIS
    Detects whether Microsoft Defender real-time protection is enabled.

.DESCRIPTION
    Intune Remediations detection script. The script checks the Microsoft
    Defender Antivirus DisableRealtimeMonitoring preference and exits 0
    when real-time protection is enabled. It exits 1 when remediation
    should run.

.NOTES
    Name:        Detect.ps1
    Version:     1.1.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Real-time protection is compliant
    Exit 1:      Real-time protection is disabled or unavailable

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

# Keep these names aligned with the folder and script file.
# Logs are written to Logs\<ScriptPackageName>\<ScriptName>.log.
$ScriptPackageName = 'Defender-Enable-Real-Time-Protection'
$ScriptName = 'Detect'

# This Defender preference is inverted. $false means the protection is enabled.
$DefenderPreferenceName = 'DisableRealtimeMonitoring'
$DesiredPreferenceValue = $false
$FriendlySettingName = 'Defender real-time protection'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp [$Level] $Message"
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

function Get-ProtectionState {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$DisablePreferenceValue
    )

    if ($DisablePreferenceValue) {
        return 'Disabled'
    }

    return 'Enabled'
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. DefenderPreferenceName='$DefenderPreferenceName'; DesiredPreferenceValue='$DesiredPreferenceValue'."

    if (-not (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue)) {
        throw 'Get-MpPreference is not available on this device.'
    }

    $preferences = Get-MpPreference
    $property = $preferences.PSObject.Properties[$DefenderPreferenceName]

    if ($null -eq $property) {
        throw "Defender preference '$DefenderPreferenceName' was not found."
    }

    if ($null -eq $property.Value) {
        throw "Defender preference '$DefenderPreferenceName' returned no value."
    }

    $currentValue = [bool]$property.Value
    $currentState = Get-ProtectionState -DisablePreferenceValue $currentValue

    if ($currentValue -eq $DesiredPreferenceValue) {
        $message = "Compliant. $FriendlySettingName is '$currentState'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. $FriendlySettingName is '$currentState'. Expected 'Enabled'."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Not compliant. Microsoft Defender preference state is unavailable.'
    exit 1
}
