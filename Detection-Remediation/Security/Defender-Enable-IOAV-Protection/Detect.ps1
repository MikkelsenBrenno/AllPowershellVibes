<#
.SYNOPSIS
    Detects Microsoft Defender IOAV protection.

.DESCRIPTION
    Intune Remediations detection script. The script checks a Microsoft Defender preference and exits 1 when remediation should set the desired state.

.NOTES
    Name:        Detect.ps1
    Version:     1.1.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Microsoft Defender IOAV protection is compliant
    Exit 1:      Microsoft Defender IOAV protection is missing, different, or unavailable

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
$ScriptPackageName = 'Defender-Enable-IOAV-Protection'
$ScriptName = 'Detect'

$PreferenceName = 'DisableIOAVProtection'
$DesiredValue = $false
$FriendlySettingName = 'Microsoft Defender IOAV protection'

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

function Get-DefenderPreferenceValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (-not (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue)) {
        throw 'Get-MpPreference is not available on this device.'
    }

    $preferences = Get-MpPreference
    if (-not $preferences.PSObject.Properties.Name.Contains($Name)) {
        throw "Defender preference '$Name' was not found on this device."
    }

    $value = $preferences.$Name
    if ($null -eq $value) {
        throw "Defender preference '$Name' returned no value."
    }

    return $value
}

function Format-BooleanValue {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return 'Unknown'
    }

    return ([bool]$Value).ToString()
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. FriendlySettingName='$FriendlySettingName'; PreferenceName='$PreferenceName'; DesiredValue='$DesiredValue'."

    $currentValue = Get-DefenderPreferenceValue -Name $PreferenceName
    if ([bool]$currentValue -eq [bool]$DesiredValue) {
        $message = "Compliant. $FriendlySettingName matches desired value '$DesiredValue'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. $FriendlySettingName current value is '$(Format-BooleanValue -Value $currentValue)'. Expected '$DesiredValue'."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "$ScriptName failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Not compliant. Microsoft Defender preference state is unavailable.'
    exit 1
}
