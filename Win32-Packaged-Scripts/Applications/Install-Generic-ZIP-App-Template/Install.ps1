<#
.SYNOPSIS
    Installs a generic ZIP-based application payload.

.DESCRIPTION
    Win32 app install script template. The script expands a packaged ZIP
    archive to a configurable install folder and writes a version marker for
    Intune detection.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      ZIP application installed
    Exit 1:      ZIP application install failed

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

$ScriptPackageName = 'Install-Generic-ZIP-App-Template'
$ScriptName = 'Install'

$ArchiveFileName = 'AppPayload.zip'
$InstallRoot = Join-Path -Path $env:ProgramFiles -ChildPath 'Contoso\ExampleZipApp'
$MarkerFileName = 'install.version'
$Version = '1.0.0'
$RemoveExistingInstallRootBeforeExtract = $false

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

    $archivePath = Join-Path -Path $PSScriptRoot -ChildPath $ArchiveFileName
    $markerPath = Join-Path -Path $InstallRoot -ChildPath $MarkerFileName

    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        throw "Archive '$archivePath' was not found. Add your ZIP payload before packaging."
    }

    if ($RemoveExistingInstallRootBeforeExtract -and (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        Remove-Item -LiteralPath $InstallRoot -Recurse -Force
    }

    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        New-Item -Path $InstallRoot -ItemType Directory -Force | Out-Null
    }

    Expand-Archive -LiteralPath $archivePath -DestinationPath $InstallRoot -Force
    Set-Content -LiteralPath $markerPath -Value $Version -Encoding UTF8

    Write-Log -Message "ZIP app installed. Archive='$archivePath'; InstallRoot='$InstallRoot'; Version='$Version'."
    Write-Output "Install succeeded. ZIP app version '$Version' is installed."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
