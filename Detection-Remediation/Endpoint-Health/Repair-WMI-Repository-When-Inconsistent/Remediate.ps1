<#
.SYNOPSIS
    Repairs inconsistent WMI repository state.

.DESCRIPTION
    Intune Remediations remediation script. The script runs a configured WMI salvage or reset action and validates the repository afterwards.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      WMI repository repair completed or reported
    Exit 1:      WMI repository repair failed

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
$ScriptName = 'Remediate'

$ExpectedVerificationText = 'consistent'
$RepairMode = 'Salvage'
$ValidationDelaySeconds = 10

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
    Write-Log -Message "Remediation started. RepairMode='$RepairMode'."

    $before = Invoke-WmiRepositoryVerification
    Write-Log -Message "WMI verification before remediation: $before"

    if ($RepairMode -eq 'ReportOnly') {
        $message = 'Report-only mode. Set $RepairMode to Salvage or Reset to repair the WMI repository.'
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message
        exit 0
    }

    if ($RepairMode -eq 'Salvage') {
        & winmgmt.exe /salvagerepository | Out-Null
    }
    elseif ($RepairMode -eq 'Reset') {
        & winmgmt.exe /resetrepository | Out-Null
    }
    else {
        throw "RepairMode '$RepairMode' is not valid. Use ReportOnly, Salvage, or Reset."
    }

    Start-Sleep -Seconds $ValidationDelaySeconds
    $after = Invoke-WmiRepositoryVerification
    Write-Log -Message "WMI verification after remediation: $after"

    if (Test-WmiRepositoryConsistent -VerificationText $after) {
        $message = "Remediation succeeded. WMI repository verification contains '$ExpectedVerificationText'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. WMI repository verification still does not contain '$ExpectedVerificationText'."
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

    Write-Output 'Remediation failed for WMI repository repair.'
    exit 1
}

