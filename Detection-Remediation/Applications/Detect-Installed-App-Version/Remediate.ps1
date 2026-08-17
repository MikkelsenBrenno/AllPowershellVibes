<#
.SYNOPSIS
    Reports that an application install or update is required.

.DESCRIPTION
    Intune Remediations remediation script. This example is intentionally
    reporting-only because application installation should normally use an
    Intune app deployment or a Win32 package.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Reporting-only mode is enabled
    Exit 1:      Application update remains required

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

$ScriptPackageName = 'Detect-Installed-App-Version'
$ScriptName = 'Remediate'

$AppDisplayNamePattern = 'Google Chrome*'
$MinimumVersion = '120.0.0.0'

# Keep false when you want Intune to keep reporting failed remediation until
# the app is deployed or updated by a proper app deployment.
$ExitZeroInReportingOnlyMode = $false

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
    Add-Content -Path $LogPath -Value "$timestamp [$Level] $Message" -Encoding UTF8
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
    Write-Log -Message "Reporting-only remediation started. AppDisplayNamePattern='$AppDisplayNamePattern'; MinimumVersion='$MinimumVersion'."
    Write-Log -Message 'Deploy or update this application with an Intune app assignment or Win32 package.' -Level 'WARN'

    Write-Output "Application matching '$AppDisplayNamePattern' must be installed or updated to at least '$MinimumVersion'."

    if ($ExitZeroInReportingOnlyMode) {
        exit 0
    }

    exit 1
}
catch {
    try {
        Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Application version remediation reporting failed.'
    exit 1
}
