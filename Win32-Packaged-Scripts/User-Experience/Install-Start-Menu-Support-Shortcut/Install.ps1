<#
.SYNOPSIS
    Installs a Start Menu support shortcut.

.DESCRIPTION
    Win32 app install script example. The script creates a configurable Start
    Menu URL shortcut and writes a local version marker for Intune detection.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Shortcut installed
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

$ScriptPackageName = 'Install-Start-Menu-Support-Shortcut'
$ScriptName = 'Install'

$ShortcutRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\Start Menu\Programs\Company'
$ShortcutFileName = 'Contact IT Support.url'
$ShortcutUrl = 'https://support.contoso.example'
$ShortcutIconFile = ''
$ShortcutIconIndex = 0

$PackageVersion = '1.0.0'
$MarkerRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Shortcuts\StartMenuSupport'
$MarkerFileName = 'support-shortcut-version.txt'

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

    if ([string]::IsNullOrWhiteSpace($ShortcutUrl)) {
        throw 'ShortcutUrl must not be empty.'
    }

    foreach ($folder in @($ShortcutRoot, $MarkerRoot)) {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        }
    }

    $shortcutPath = Join-Path -Path $ShortcutRoot -ChildPath $ShortcutFileName
    $shortcutContent = @(
        '[InternetShortcut]'
        "URL=$ShortcutUrl"
    )

    if (-not [string]::IsNullOrWhiteSpace($ShortcutIconFile)) {
        $shortcutContent += "IconFile=$ShortcutIconFile"
        $shortcutContent += "IconIndex=$ShortcutIconIndex"
    }

    Set-Content -LiteralPath $shortcutPath -Value $shortcutContent -Encoding ASCII -Force

    $markerPath = Join-Path -Path $MarkerRoot -ChildPath $MarkerFileName
    Set-Content -LiteralPath $markerPath -Value $PackageVersion -Encoding ASCII -Force

    Write-Log -Message "Created shortcut '$shortcutPath' with URL '$ShortcutUrl'."
    Write-Output "Install succeeded. Support shortcut version '$PackageVersion' installed to '$shortcutPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
