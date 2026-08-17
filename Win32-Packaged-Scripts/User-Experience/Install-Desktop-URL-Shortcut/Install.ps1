<#
.SYNOPSIS
    Installs an all-users desktop URL shortcut.

.DESCRIPTION
    Win32 app install script example. The script creates a configurable URL
    shortcut on the public desktop and writes a version marker for detection.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Desktop URL shortcut installed
    Exit 1:      Desktop URL shortcut install failed

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

$ScriptPackageName = 'Install-Desktop-URL-Shortcut'
$ScriptName = 'Install'

$ShortcutRoot = [Environment]::GetFolderPath('CommonDesktopDirectory')
$ShortcutFileName = 'Company Portal.url'
$ShortcutUrl = 'https://portal.manage.microsoft.com'
$PackageVersion = '1.0.0'
$MarkerRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Shortcuts\DesktopUrl'
$MarkerFileName = 'desktop-url-version.txt'

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

    foreach ($folder in @($ShortcutRoot, $MarkerRoot)) {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) {
            New-Item -Path $folder -ItemType Directory -Force | Out-Null
        }
    }

    $shortcutPath = Join-Path -Path $ShortcutRoot -ChildPath $ShortcutFileName
    Set-Content -LiteralPath $shortcutPath -Value @('[InternetShortcut]', "URL=$ShortcutUrl") -Encoding ASCII -Force
    Set-Content -LiteralPath (Join-Path -Path $MarkerRoot -ChildPath $MarkerFileName) -Value $PackageVersion -Encoding ASCII -Force

    Write-Output "Install succeeded. Desktop URL shortcut version '$PackageVersion' installed."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
