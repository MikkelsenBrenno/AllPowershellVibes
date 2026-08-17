<#
.SYNOPSIS
    Installs a file-based version marker.

.DESCRIPTION
    Win32 app install script example. The script creates a configurable
    marker file containing an expected version and validates the final file
    content.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Installation succeeded
    Exit 1:      Installation failed

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
$ScriptPackageName = 'Example-Install-File-Version-Marker'
$ScriptName = 'Install'

# Change these values for your package.
$InstallRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ExampleFileVersionMarker'
$MarkerFileName = 'installed-version.txt'
$InstalledVersion = '1.0.0'

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
    Write-Log -Message "Install started. InstallRoot='$InstallRoot'; MarkerFileName='$MarkerFileName'; InstalledVersion='$InstalledVersion'."

    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        New-Item -Path $InstallRoot -ItemType Directory -Force | Out-Null
    }

    $markerPath = Join-Path -Path $InstallRoot -ChildPath $MarkerFileName
    Set-Content -LiteralPath $markerPath -Value $InstalledVersion -Encoding ASCII -Force

    $actualVersion = (Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop).Trim()

    if ($actualVersion -ne $InstalledVersion) {
        throw "Marker validation failed. Expected '$InstalledVersion' but found '$actualVersion'."
    }

    $message = "Install succeeded. Marker file '$markerPath' contains version '$actualVersion'."
    Write-Log -Message $message
    Write-Output $message
    exit 0
}
catch {
    try {
        Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Install failed.'
    exit 1
}
