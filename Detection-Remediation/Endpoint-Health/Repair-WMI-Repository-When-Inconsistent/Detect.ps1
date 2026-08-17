<#
.SYNOPSIS
    Detects inconsistent WMI repository state.

.DESCRIPTION
    Intune Remediations detection script. The script runs WMI repository verification and exits 1 when the output is not consistent.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      WMI repository is consistent
    Exit 1:      WMI repository is inconsistent or unavailable

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
$ScriptPackageName = 'Repair-WMI-Repository-When-Inconsistent'
$ScriptName = 'Detect'

$ExpectedVerificationText = 'consistent'

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

function Invoke-WmiRepositoryVerification {
    if (-not (Get-Command -Name winmgmt.exe -ErrorAction SilentlyContinue)) {
        throw 'winmgmt.exe is not available on this device.'
    }

    return (@(& winmgmt.exe /verifyrepository 2>&1) -join ' ').Trim()
}

function Test-WmiRepositoryConsistent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VerificationText
    )

    if ([string]::IsNullOrWhiteSpace($ExpectedVerificationText)) {
        throw 'ExpectedVerificationText must not be empty.'
    }

    return ($VerificationText -match [regex]::Escape($ExpectedVerificationText))
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. ExpectedVerificationText='$ExpectedVerificationText'. Running WMI repository verification."

    $verificationText = Invoke-WmiRepositoryVerification
    Write-Log -Message "WMI verification output: $verificationText"

    if (Test-WmiRepositoryConsistent -VerificationText $verificationText) {
        $message = "Compliant. WMI repository verification contains '$ExpectedVerificationText'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. WMI repository verification did not contain '$ExpectedVerificationText'."
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

    Write-Output 'Not compliant. WMI repository state could not be validated.'
    exit 1
}

