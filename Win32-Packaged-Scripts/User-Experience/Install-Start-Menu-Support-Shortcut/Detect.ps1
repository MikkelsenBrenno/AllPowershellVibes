<#
.SYNOPSIS
    Detects a Start Menu support shortcut.

.DESCRIPTION
    Win32 app detection script example. The script checks that the configured
    Start Menu URL shortcut exists, points to the expected URL, and has the
    expected version marker.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Detection
    Exit 0:      Shortcut detected, with STDOUT
    Exit 1:      Shortcut missing or incorrect

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
$ScriptName = 'Detect'

$ShortcutRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\Start Menu\Programs\Company'
$ShortcutFileName = 'Contact IT Support.url'
$ShortcutUrl = 'https://support.contoso.example'

$ExpectedPackageVersion = '1.0.0'
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

    $shortcutPath = Join-Path -Path $ShortcutRoot -ChildPath $ShortcutFileName
    $markerPath = Join-Path -Path $MarkerRoot -ChildPath $MarkerFileName

    if (-not (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) {
        Write-Log -Message "Shortcut '$shortcutPath' was not found." -Level 'WARN'
        exit 1
    }

    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        Write-Log -Message "Marker '$markerPath' was not found." -Level 'WARN'
        exit 1
    }

    $shortcutRaw = Get-Content -LiteralPath $shortcutPath -Raw -ErrorAction Stop
    $actualVersion = (Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop).Trim()

    if ($shortcutRaw -match [regex]::Escape("URL=$ShortcutUrl") -and $actualVersion -eq $ExpectedPackageVersion) {
        Write-Output "Detected. Support shortcut version '$actualVersion' is installed."
        exit 0
    }

    Write-Log -Message "Shortcut or marker mismatch. ExpectedUrl='$ShortcutUrl'; ActualVersion='$actualVersion'; ExpectedVersion='$ExpectedPackageVersion'." -Level 'WARN'
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    exit 1
}
