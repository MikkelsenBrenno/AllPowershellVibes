<#
.SYNOPSIS
    <Short description of what this script does.>

.DESCRIPTION
    <Longer description of the intended Intune use case.>

.NOTES
    Name:        <ScriptName.ps1>
    Author:      <Author or team>
    Version:     1.0.0
    Created:     <YYYY-MM-DD>
    Updated:     <YYYY-MM-DD>
    PowerShell:  Windows PowerShell 5.1
    Context:     <System or User>

.INTUNE
    Workload:    <Remediation | Custom Compliance | Platform Script | Win32 App>
    Exit 0:      <Meaning for this workload>
    Exit 1:      <Meaning for this workload>

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
$ScriptPackageName = '<Script-Folder-Name>'
$ScriptName = '<ScriptName>'

# Change these values for your environment.
$ExampleSetting = 'ExampleValue'

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
    Write-Log -Message 'Script started.'

    # Add script logic here.

    Write-Log -Message 'Script completed successfully.'
    exit 0
}
catch {
    try {
        Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
        # Avoid masking the original error if logging fails.
    }

    exit 1
}
