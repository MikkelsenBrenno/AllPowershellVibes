<#
.SYNOPSIS
    Removes a Start Menu support shortcut.

.DESCRIPTION
    Win32 app uninstall script example. The script removes only the configured
    URL shortcut and local version marker created by this package.

.NOTES
    Name:        Uninstall.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Shortcut removed
    Exit 1:      Shortcut removal failed

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

$ScriptPackageName = 'Install-Start-Menu-Support-Shortcut'
$ScriptName = 'Uninstall'

$ShortcutRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\Start Menu\Programs\Company'
$ShortcutFileName = 'Contact IT Support.url'

$MarkerRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Shortcuts\StartMenuSupport'
$MarkerFileName = 'support-shortcut-version.txt'

$RemoveShortcutRootWhenEmpty = $true
$RemoveMarkerRootWhenEmpty = $true

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Remove-FolderWhenEmpty {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path -PathType Container) {
        $remainingItems = @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue)

        if ($remainingItems.Count -eq 0) {
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
        }
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $shortcutPath = Join-Path -Path $ShortcutRoot -ChildPath $ShortcutFileName
    $markerPath = Join-Path -Path $MarkerRoot -ChildPath $MarkerFileName

    foreach ($path in @($shortcutPath, $markerPath)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            Remove-Item -LiteralPath $path -Force -ErrorAction Stop
            Write-Log -Message "Removed '$path'."
        }
    }

    if ($RemoveShortcutRootWhenEmpty) {
        Remove-FolderWhenEmpty -Path $ShortcutRoot
    }

    if ($RemoveMarkerRootWhenEmpty) {
        Remove-FolderWhenEmpty -Path $MarkerRoot
    }

    Write-Output 'Uninstall succeeded. Configured support shortcut and marker are absent.'
    exit 0
}
catch {
    try { Write-Log -Message "Uninstall failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Uninstall failed.'
    exit 1
}
