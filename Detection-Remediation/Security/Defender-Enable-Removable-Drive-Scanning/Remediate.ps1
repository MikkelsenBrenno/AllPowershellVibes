<#
.SYNOPSIS
    Remediates Microsoft Defender removable drive scanning.

.DESCRIPTION
    Intune Remediations remediation script. The script sets the configured Microsoft Defender preference and validates the final state.

.NOTES
    Name:        Remediate.ps1
    Version:     1.1.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Microsoft Defender removable drive scanning remediated
    Exit 1:      Microsoft Defender removable drive scanning remediation failed

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
$ScriptPackageName = 'Defender-Enable-Removable-Drive-Scanning'
$ScriptName = 'Remediate'

$PreferenceName = 'DisableRemovableDriveScanning'
$DesiredValue = $false
$FriendlySettingName = 'Microsoft Defender removable drive scanning'
$ValidationDelaySeconds = 3

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
    Write-Log -Message "Remediation started. FriendlySettingName='$FriendlySettingName'; PreferenceName='$PreferenceName'; DesiredValue='$DesiredValue'."

    if (-not (Get-Command -Name Set-MpPreference -ErrorAction SilentlyContinue)) {
        throw 'Set-MpPreference is not available on this device.'
    }

    $setCommand = Get-Command -Name Set-MpPreference
    if (-not $setCommand.Parameters.ContainsKey($PreferenceName)) {
        throw "Set-MpPreference does not expose parameter '$PreferenceName' on this device."
    }

    $before = Get-DefenderPreferenceValue -Name $PreferenceName
    Write-Log -Message "$FriendlySettingName before remediation: '$(Format-BooleanValue -Value $before)'."

    if ([bool]$before -ne [bool]$DesiredValue) {
        $arguments = @{}
        $arguments[$PreferenceName] = [bool]$DesiredValue
        Set-MpPreference @arguments
    }

    Start-Sleep -Seconds $ValidationDelaySeconds

    $after = Get-DefenderPreferenceValue -Name $PreferenceName
    if ([bool]$after -eq [bool]$DesiredValue) {
        $message = "Remediation succeeded. $FriendlySettingName matches desired value '$DesiredValue'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. $FriendlySettingName current value is '$(Format-BooleanValue -Value $after)'. Expected '$DesiredValue'."
    Write-Log -Message $message -Level 'ERROR'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "$ScriptName failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Remediation failed for Microsoft Defender removable drive scanning.'
    exit 1
}
