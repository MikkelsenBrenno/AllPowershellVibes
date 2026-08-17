<#
.SYNOPSIS
    Detects whether Microsoft Defender cloud protection is configured.

.DESCRIPTION
    Intune Remediations detection script. The script checks Microsoft
    Defender Antivirus MAPSReporting and SubmitSamplesConsent preferences
    and exits 0 when both match the configured desired values.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Cloud protection settings are compliant
    Exit 1:      Cloud protection settings are different or unavailable

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
$ScriptPackageName = 'Defender-Enable-Cloud-Protection'
$ScriptName = 'Detect'

# Choose one of: Disabled, Basic, Advanced.
$DesiredMAPSReporting = 'Advanced'

# Choose one of: AlwaysPrompt, SendSafeSamples, NeverSend, SendAllSamples.
# Review privacy requirements before using SendAllSamples.
$DesiredSubmitSamplesConsent = 'SendSafeSamples'

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

function Convert-MAPSReportingValue {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value
    )

    if ($null -eq $Value) {
        return 'Unknown'
    }

    $valueText = $Value.ToString()
    $valueMap = @{
        '0' = 'Disabled'
        '1' = 'Basic'
        '2' = 'Advanced'
    }

    if ($valueMap.ContainsKey($valueText)) {
        return $valueMap[$valueText]
    }

    return $valueText
}

function Convert-SubmitSamplesConsentValue {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value
    )

    if ($null -eq $Value) {
        return 'Unknown'
    }

    $valueText = $Value.ToString()
    $valueMap = @{
        '0' = 'AlwaysPrompt'
        '1' = 'SendSafeSamples'
        '2' = 'NeverSend'
        '3' = 'SendAllSamples'
    }

    if ($valueMap.ContainsKey($valueText)) {
        return $valueMap[$valueText]
    }

    return $valueText
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. DesiredMAPSReporting='$DesiredMAPSReporting'; DesiredSubmitSamplesConsent='$DesiredSubmitSamplesConsent'."

    if ($DesiredMAPSReporting -notin @('Disabled', 'Basic', 'Advanced')) {
        throw "DesiredMAPSReporting '$DesiredMAPSReporting' is not valid."
    }

    if ($DesiredSubmitSamplesConsent -notin @('AlwaysPrompt', 'SendSafeSamples', 'NeverSend', 'SendAllSamples')) {
        throw "DesiredSubmitSamplesConsent '$DesiredSubmitSamplesConsent' is not valid."
    }

    if (-not (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue)) {
        throw 'Get-MpPreference is not available on this device.'
    }

    $preferences = Get-MpPreference
    $currentMAPSReporting = Convert-MAPSReportingValue -Value $preferences.MAPSReporting
    $currentSubmitSamplesConsent = Convert-SubmitSamplesConsentValue -Value $preferences.SubmitSamplesConsent

    if ($currentMAPSReporting -eq $DesiredMAPSReporting -and $currentSubmitSamplesConsent -eq $DesiredSubmitSamplesConsent) {
        $message = "Compliant. Defender cloud protection settings match desired values."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. MAPSReporting='$currentMAPSReporting'; SubmitSamplesConsent='$currentSubmitSamplesConsent'."
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

    Write-Output 'Not compliant. Defender cloud protection could not be validated.'
    exit 1
}

