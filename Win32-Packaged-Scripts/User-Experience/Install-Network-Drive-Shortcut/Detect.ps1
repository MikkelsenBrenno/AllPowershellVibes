<#
.SYNOPSIS
    Detects a network drive shortcut.

.DESCRIPTION
    Win32 app detection script example. The script validates that a .lnk
    shortcut exists and points to the expected UNC path.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System or user, depending on shortcut location

.INTUNE
    Workload:    Win32 App
    Exit 0:      Shortcut detected
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

$ScriptPackageName = 'Install-Network-Drive-Shortcut'
$ScriptName = 'Detect'

$ShortcutFolder = Join-Path -Path $env:PUBLIC -ChildPath 'Desktop'
$ShortcutName = 'Contoso Share.lnk'
$TargetPath = '\\fileserver\Share'

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
    $shortcutPath = Join-Path -Path $ShortcutFolder -ChildPath $ShortcutName

    if (-not (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) {
        Write-Output "Not detected. Shortcut '$shortcutPath' is missing."
        exit 1
    }

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)

    if ($shortcut.TargetPath -eq $TargetPath) {
        Write-Output "Detected. Shortcut '$shortcutPath' points to '$TargetPath'."
        exit 0
    }

    Write-Output "Not detected. Shortcut target is '$($shortcut.TargetPath)'."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not detected. Shortcut '$ShortcutName' could not be validated."
    exit 1
}
