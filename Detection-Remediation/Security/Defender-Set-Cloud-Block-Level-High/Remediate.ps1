<#
.SYNOPSIS
    Sets the Microsoft Defender cloud block level.

.DESCRIPTION
    Intune Remediations remediation script. The script sets the Defender CloudBlockLevel preference and validates the final state.

.NOTES
    Name:        Remediate.ps1
    Version:     1.1.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Cloud block level remediated
    Exit 1:      Cloud block level remediation failed

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
$ScriptPackageName = 'Defender-Set-Cloud-Block-Level-High'
$ScriptName = 'Remediate'

$DesiredCloudBlockLevel = 'High'
$AllowedCloudBlockLevels = @('Default', 'High', 'HighPlus', 'ZeroTolerance')
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

function Get-CloudBlockLevel {
    if (-not (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue)) {
        throw 'Get-MpPreference is not available on this device.'
    }

    $preferences = Get-MpPreference
    return [string]$preferences.CloudBlockLevel
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. DesiredCloudBlockLevel='$DesiredCloudBlockLevel'."

    if ($DesiredCloudBlockLevel -notin $AllowedCloudBlockLevels) {
        throw "DesiredCloudBlockLevel '$DesiredCloudBlockLevel' is not valid."
    }

    if (-not (Get-Command -Name Set-MpPreference -ErrorAction SilentlyContinue)) {
        throw 'Set-MpPreference is not available on this device.'
    }

    $before = Get-CloudBlockLevel
    Write-Log -Message "Cloud block level before remediation: '$before'."

    if ($before -ne $DesiredCloudBlockLevel) {
        Set-MpPreference -CloudBlockLevel $DesiredCloudBlockLevel
    }

    Start-Sleep -Seconds $ValidationDelaySeconds
    $after = Get-CloudBlockLevel

    if ($after -eq $DesiredCloudBlockLevel) {
        $message = "Remediation succeeded. Defender cloud block level is '$after'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. Defender cloud block level is '$after'. Expected '$DesiredCloudBlockLevel'."
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

    Write-Output 'Remediation failed for Defender cloud block level.'
    exit 1
}
