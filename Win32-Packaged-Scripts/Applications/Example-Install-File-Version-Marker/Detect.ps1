<#
.SYNOPSIS
    Detects a file-based version marker.

.DESCRIPTION
    Win32 app custom detection script example. Intune considers the app
    detected only when this script exits 0 and writes a string to STDOUT.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Detection
    Exit 0:      Marker detected, with STDOUT
    Exit 1:      Marker missing or version mismatch

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
$ScriptName = 'Detect'

# Use the same values as Install.ps1.
$InstallRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ExampleFileVersionMarker'
$MarkerFileName = 'installed-version.txt'
$ExpectedVersion = '1.0.0'

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

    $markerPath = Join-Path -Path $InstallRoot -ChildPath $MarkerFileName
    Write-Log -Message "Detection started. MarkerPath='$markerPath'; ExpectedVersion='$ExpectedVersion'."

    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        Write-Log -Message 'Not detected. Marker file does not exist.' -Level 'WARN'
        exit 1
    }

    $actualVersion = (Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop).Trim()

    if ($actualVersion -eq $ExpectedVersion) {
        $message = "Detected. Marker version is '$actualVersion'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    Write-Log -Message "Not detected. Expected version '$ExpectedVersion' but found '$actualVersion'." -Level 'WARN'
    exit 1
}
catch {
    try {
        Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    exit 1
}
