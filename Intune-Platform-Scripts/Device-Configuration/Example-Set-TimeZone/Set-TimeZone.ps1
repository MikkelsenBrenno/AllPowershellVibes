<#
.SYNOPSIS
    Sets the Windows time zone.

.DESCRIPTION
    Intune platform script example. The script sets the device time zone
    with tzutil.exe and validates the final state.

.NOTES
    Name:        Set-TimeZone.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Platform Script
    Exit 0:      Time zone is already correct or was changed successfully
    Exit 1:      Time zone could not be validated or changed

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
$ScriptPackageName = 'Example-Set-TimeZone'
$ScriptName = 'Set-TimeZone'

# Change this to the Windows time zone ID required by your organization.
# Run "tzutil.exe /l" on a Windows device to list valid IDs.
$TargetTimeZoneId = 'UTC'

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

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Script started. TargetTimeZoneId='$TargetTimeZoneId'."

    $tzutil = Join-Path -Path $env:SystemRoot -ChildPath 'System32\tzutil.exe'

    if (-not (Test-Path -LiteralPath $tzutil)) {
        throw "tzutil.exe was not found at '$tzutil'."
    }

    $currentTimeZone = (& $tzutil /g).Trim()
    Write-Log -Message "Current time zone is '$currentTimeZone'."

    if ($currentTimeZone -eq $TargetTimeZoneId) {
        $message = "Time zone is already '$TargetTimeZoneId'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    Write-Log -Message "Setting time zone to '$TargetTimeZoneId'."
    & $tzutil /s $TargetTimeZoneId

    if ($LASTEXITCODE -ne 0) {
        throw "tzutil.exe exited with code $LASTEXITCODE."
    }

    $updatedTimeZone = (& $tzutil /g).Trim()
    Write-Log -Message "Updated time zone is '$updatedTimeZone'."

    if ($updatedTimeZone -ne $TargetTimeZoneId) {
        throw "Time zone validation failed. Expected '$TargetTimeZoneId' but found '$updatedTimeZone'."
    }

    $message = "Time zone set to '$TargetTimeZoneId'."
    Write-Log -Message $message
    Write-Output $message
    exit 0
}
catch {
    try {
        Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output "Failed to set time zone to '$TargetTimeZoneId'."
    exit 1
}

