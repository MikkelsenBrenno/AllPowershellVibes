<#
.SYNOPSIS
    Installs a network drive shortcut.

.DESCRIPTION
    Win32 app install script example. The script creates a configurable .lnk
    shortcut to a UNC path.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System or user, depending on shortcut location

.INTUNE
    Workload:    Win32 App
    Exit 0:      Shortcut install succeeded
    Exit 1:      Shortcut install failed

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

$ScriptPackageName = 'Install-Network-Drive-Shortcut'
$ScriptName = 'Install'

$ShortcutFolder = Join-Path -Path $env:PUBLIC -ChildPath 'Desktop'
$ShortcutName = 'Contoso Share.lnk'
$TargetPath = '\\fileserver\Share'
$Description = 'Open the Contoso network share'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if ($TargetPath -eq '\\fileserver\Share') {
        throw 'Replace the TargetPath placeholder before deployment.'
    }

    if (-not (Test-Path -LiteralPath $ShortcutFolder -PathType Container)) {
        New-Item -Path $ShortcutFolder -ItemType Directory -Force | Out-Null
    }

    $shortcutPath = Join-Path -Path $ShortcutFolder -ChildPath $ShortcutName
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $TargetPath
    $shortcut.Description = $Description
    $shortcut.Save()

    if (-not (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) {
        throw "Shortcut '$shortcutPath' was not created."
    }

    Write-Output "Install succeeded. Shortcut '$shortcutPath' points to '$TargetPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Install failed for shortcut '$ShortcutName'."
    exit 1
}
