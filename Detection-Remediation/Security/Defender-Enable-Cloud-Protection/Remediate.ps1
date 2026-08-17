<#
.SYNOPSIS
    Configures Microsoft Defender cloud protection.

.DESCRIPTION
    Intune Remediations remediation script. The script sets Microsoft
    Defender Antivirus MAPSReporting and SubmitSamplesConsent preferences
    to the configured desired values and validates the final state.

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
$ScriptPackageName = 'Defender-Enable-Cloud-Protection'
$ScriptName = 'Remediate'

# Choose one of: Disabled, Basic, Advanced.
$DesiredMAPSReporting = 'Advanced'

# Choose one of: AlwaysPrompt, SendSafeSamples, NeverSend, SendAllSamples.
# Review privacy requirements before using SendAllSamples.
$DesiredSubmitSamplesConsent = 'SendSafeSamples'

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
    Write-Log -Message "Remediation started. DesiredMAPSReporting='$DesiredMAPSReporting'; DesiredSubmitSamplesConsent='$DesiredSubmitSamplesConsent'."

    if ($DesiredMAPSReporting -notin @('Disabled', 'Basic', 'Advanced')) {
        throw "DesiredMAPSReporting '$DesiredMAPSReporting' is not valid."
    }

    if ($DesiredSubmitSamplesConsent -notin @('AlwaysPrompt', 'SendSafeSamples', 'NeverSend', 'SendAllSamples')) {
        throw "DesiredSubmitSamplesConsent '$DesiredSubmitSamplesConsent' is not valid."
    }

    if (-not (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue)) {
        throw 'Get-MpPreference is not available on this device.'
    }

    if (-not (Get-Command -Name Set-MpPreference -ErrorAction SilentlyContinue)) {
        throw 'Set-MpPreference is not available on this device.'
    }

    $before = Get-MpPreference
    Write-Log -Message "Before remediation: MAPSReporting='$(Convert-MAPSReportingValue -Value $before.MAPSReporting)'; SubmitSamplesConsent='$(Convert-SubmitSamplesConsentValue -Value $before.SubmitSamplesConsent)'."

    Set-MpPreference -MAPSReporting $DesiredMAPSReporting -SubmitSamplesConsent $DesiredSubmitSamplesConsent

    Start-Sleep -Seconds $ValidationDelaySeconds

    $after = Get-MpPreference
    $afterMAPSReporting = Convert-MAPSReportingValue -Value $after.MAPSReporting
    $afterSubmitSamplesConsent = Convert-SubmitSamplesConsentValue -Value $after.SubmitSamplesConsent

    if ($afterMAPSReporting -eq $DesiredMAPSReporting -and $afterSubmitSamplesConsent -eq $DesiredSubmitSamplesConsent) {
        $message = "Remediation succeeded. Defender cloud protection settings match desired values."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. MAPSReporting='$afterMAPSReporting'; SubmitSamplesConsent='$afterSubmitSamplesConsent'."
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

    Write-Output 'Remediation failed for Defender cloud protection.'
    exit 1
}

