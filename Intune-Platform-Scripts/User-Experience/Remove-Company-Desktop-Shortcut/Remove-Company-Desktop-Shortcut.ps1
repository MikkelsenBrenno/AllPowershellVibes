<#
.SYNOPSIS
    Removes a desktop URL shortcut.

.DESCRIPTION
    Intune platform script example. The script removes a configurable
    shortcut from a configurable desktop folder and validates that it is gone.

.NOTES
    Name:        Remove-Company-Desktop-Shortcut.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Shortcut is absent
    Exit 1:      Shortcut could not be removed

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

$ScriptPackageName = 'Remove-Company-Desktop-Shortcut'
$ScriptName = 'Remove-Company-Desktop-Shortcut'

$ShortcutName = 'Company Support Portal'
$ShortcutFolder = Join-Path -Path $env:Public -ChildPath 'Desktop'
$ShortcutExtension = '.url'

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
    param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO')
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

    $shortcutPath = Join-Path -Path $ShortcutFolder -ChildPath "$ShortcutName$ShortcutExtension"
    Write-Log -Message "Script started. ShortcutPath='$shortcutPath'."

    if (Test-Path -LiteralPath $shortcutPath -PathType Leaf) {
        Remove-Item -LiteralPath $shortcutPath -Force
        Write-Log -Message "Removed shortcut '$shortcutPath'."
    }
    else {
        Write-Log -Message "Shortcut '$shortcutPath' is already absent."
    }

    if (Test-Path -LiteralPath $shortcutPath -PathType Leaf) {
        throw "Shortcut '$shortcutPath' still exists after removal."
    }

    $message = "Shortcut is absent: '$shortcutPath'."
    Write-Log -Message $message
    Write-Output $message
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Failed to remove shortcut '$ShortcutName'."
    exit 1
}
