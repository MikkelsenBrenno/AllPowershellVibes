<#
.SYNOPSIS
    Detects an all-users desktop URL shortcut.

.DESCRIPTION
    Win32 app detection script example. The script checks shortcut content and
    version marker.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Detection
    Exit 0:      Desktop URL shortcut detected, with STDOUT
    Exit 1:      Desktop URL shortcut missing or incorrect

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
$ScriptName = 'Detect'

$ShortcutRoot = [Environment]::GetFolderPath('CommonDesktopDirectory')
$ShortcutFileName = 'Company Portal.url'
$ShortcutUrl = 'https://portal.manage.microsoft.com'
$ExpectedPackageVersion = '1.0.0'
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

    $shortcutPath = Join-Path -Path $ShortcutRoot -ChildPath $ShortcutFileName
    $markerPath = Join-Path -Path $MarkerRoot -ChildPath $MarkerFileName

    if ((Test-Path -LiteralPath $shortcutPath -PathType Leaf) -and (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        $shortcutRaw = Get-Content -LiteralPath $shortcutPath -Raw -ErrorAction Stop
        $actualVersion = (Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop).Trim()
        if ($shortcutRaw -match [regex]::Escape("URL=$ShortcutUrl") -and $actualVersion -eq $ExpectedPackageVersion) {
            Write-Output "Detected. Desktop URL shortcut version '$actualVersion' is installed."
            exit 0
        }
    }

    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    exit 1
}
