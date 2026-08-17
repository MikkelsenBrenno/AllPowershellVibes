<#
.SYNOPSIS
    Creates a desktop URL shortcut.

.DESCRIPTION
    Intune platform script example. The script creates or updates a
    configurable URL shortcut on the public desktop and validates the final
    shortcut target.

.NOTES
    Name:        Create-Company-Desktop-Shortcut.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Shortcut exists and points to the expected URL
    Exit 1:      Shortcut could not be created or validated

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
$ScriptPackageName = 'Create-Company-Desktop-Shortcut'
$ScriptName = 'Create-Company-Desktop-Shortcut'

# Change these values for your organization.
$ShortcutName = 'Company Support Portal'
$ShortcutUrl = 'https://example.com/support'
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

function Get-ShortcutPath {
    $fileName = "$ShortcutName$ShortcutExtension"
    return (Join-Path -Path $ShortcutFolder -ChildPath $fileName)
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Script started. ShortcutName='$ShortcutName'; ShortcutUrl='$ShortcutUrl'; ShortcutFolder='$ShortcutFolder'."

    if ([string]::IsNullOrWhiteSpace($ShortcutName)) {
        throw 'ShortcutName cannot be empty.'
    }

    if ([string]::IsNullOrWhiteSpace($ShortcutUrl) -or $ShortcutUrl -notmatch '^https?://') {
        throw "ShortcutUrl '$ShortcutUrl' must start with http:// or https://."
    }

    if (-not (Test-Path -LiteralPath $ShortcutFolder -PathType Container)) {
        Write-Log -Message "Creating shortcut folder '$ShortcutFolder'."
        New-Item -Path $ShortcutFolder -ItemType Directory -Force | Out-Null
    }

    $shortcutPath = Get-ShortcutPath
    $shortcutContent = @(
        '[InternetShortcut]'
        "URL=$ShortcutUrl"
    )

    Write-Log -Message "Writing shortcut '$shortcutPath'."
    Set-Content -LiteralPath $shortcutPath -Value $shortcutContent -Encoding ASCII -Force

    $writtenContent = Get-Content -LiteralPath $shortcutPath -Raw -ErrorAction Stop

    if ($writtenContent -notmatch [regex]::Escape("URL=$ShortcutUrl")) {
        throw "Shortcut validation failed. Expected URL '$ShortcutUrl'."
    }

    $message = "Shortcut created or updated: '$shortcutPath'."
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

    Write-Output "Failed to create shortcut '$ShortcutName'."
    exit 1
}
