<#
.SYNOPSIS
    Removes a file-based version marker.

.DESCRIPTION
    Win32 app uninstall script example. The script removes the configured
    marker file and optionally removes the dedicated package folder.

.NOTES
    Name:        Uninstall.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Uninstallation succeeded
    Exit 1:      Uninstallation failed

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
$ScriptName = 'Uninstall'

# Use the same location as Install.ps1.
$InstallRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ExampleFileVersionMarker'
$MarkerFileName = 'installed-version.txt'

# Keep this true only when InstallRoot is dedicated to this package.
$RemoveInstallRootWhenEmpty = $true

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
    Write-Log -Message "Uninstall started. MarkerPath='$markerPath'."

    if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
        Remove-Item -LiteralPath $markerPath -Force
        Write-Log -Message "Removed marker file '$markerPath'."
    }
    else {
        Write-Log -Message 'Marker file is already absent.'
    }

    if ($RemoveInstallRootWhenEmpty -and (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        $remainingItems = @(Get-ChildItem -LiteralPath $InstallRoot -Force)

        if ($remainingItems.Count -eq 0) {
            Remove-Item -LiteralPath $InstallRoot -Force
            Write-Log -Message "Removed empty install root '$InstallRoot'."
        }
    }

    if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
        throw "Marker file '$markerPath' still exists after uninstall."
    }

    $message = 'Uninstall succeeded.'
    Write-Log -Message $message
    Write-Output $message
    exit 0
}
catch {
    try {
        Write-Log -Message "Uninstall failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Uninstall failed.'
    exit 1
}
