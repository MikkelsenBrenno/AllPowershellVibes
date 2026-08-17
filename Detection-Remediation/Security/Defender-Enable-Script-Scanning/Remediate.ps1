<#
.SYNOPSIS
    Enables Microsoft Defender script scanning.

.DESCRIPTION
    Intune Remediations remediation script. The script sets the Microsoft
    Defender Antivirus DisableScriptScanning preference to false and
    validates that script scanning is enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation succeeded
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

# Keep these names aligned with the folder and script file.
# Logs are written to Logs\<ScriptPackageName>\<ScriptName>.log.
$ScriptPackageName = 'Defender-Enable-Script-Scanning'
$ScriptName = 'Remediate'

# This Defender preference is inverted. $false means the protection is enabled.
$DefenderPreferenceName = 'DisableScriptScanning'
$DesiredPreferenceValue = $false
$FriendlySettingName = 'Defender script scanning'

# Increase this if policy or platform state needs more time before validation.
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
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
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
    Write-Log -Message "Remediation started. DefenderPreferenceName='$DefenderPreferenceName'; DesiredPreferenceValue='$DesiredPreferenceValue'."

    if (-not (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue)) {
        throw 'Get-MpPreference is not available on this device.'
    }

    if (-not (Get-Command -Name Set-MpPreference -ErrorAction SilentlyContinue)) {
        throw 'Set-MpPreference is not available on this device.'
    }

    $beforePreferences = Get-MpPreference
    $beforeProperty = $beforePreferences.PSObject.Properties[$DefenderPreferenceName]

    if ($null -eq $beforeProperty) {
        throw "Defender preference '$DefenderPreferenceName' was not found."
    }

    $beforeValue = [bool]$beforeProperty.Value
    Write-Log -Message "Current $FriendlySettingName state is '$(Get-ProtectionState -DisablePreferenceValue $beforeValue)'."

    if ($beforeValue -ne $DesiredPreferenceValue) {
        $parameters = @{
            $DefenderPreferenceName = $DesiredPreferenceValue
        }

        Write-Log -Message "Setting '$DefenderPreferenceName' to '$DesiredPreferenceValue'."
        Set-MpPreference @parameters
    }

    Start-Sleep -Seconds $ValidationDelaySeconds

    $afterPreferences = Get-MpPreference
    $afterValue = [bool]$afterPreferences.PSObject.Properties[$DefenderPreferenceName].Value
    $afterState = Get-ProtectionState -DisablePreferenceValue $afterValue

    if ($afterValue -eq $DesiredPreferenceValue) {
        $message = "Remediation succeeded. $FriendlySettingName is '$afterState'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. $FriendlySettingName is '$afterState'. Expected 'Enabled'."
    Write-Log -Message $message -Level 'ERROR'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output "Remediation failed for $FriendlySettingName."
    exit 1
}

