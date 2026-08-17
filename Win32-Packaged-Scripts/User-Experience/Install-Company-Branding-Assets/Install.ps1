<#
.SYNOPSIS
    Installs company branding assets.

.DESCRIPTION
    Win32 app install script example. The script copies configurable branding
    files from the package folder to a local ProgramData folder and writes a
    version marker for detection.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Branding assets installed
    Exit 1:      Branding asset install failed

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

$ScriptPackageName = 'Install-Company-Branding-Assets'
$ScriptName = 'Install'

$BrandingRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Branding'
$BrandingVersion = '1.0.0'
$MarkerFileName = 'branding-version.txt'
$AssetFileNames = @(
    'CompanyWallpaper.jpg',
    'CompanyLogo.png'
)

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

    if (-not (Test-Path -LiteralPath $BrandingRoot -PathType Container)) {
        New-Item -Path $BrandingRoot -ItemType Directory -Force | Out-Null
    }

    foreach ($assetFileName in $AssetFileNames) {
        $sourcePath = Join-Path -Path $PSScriptRoot -ChildPath $assetFileName
        $destinationPath = Join-Path -Path $BrandingRoot -ChildPath $assetFileName

        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Asset file '$sourcePath' was not found. Add the file to the package folder or update AssetFileNames."
        }

        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
        Write-Log -Message "Copied branding asset '$assetFileName' to '$destinationPath'."
    }

    $markerPath = Join-Path -Path $BrandingRoot -ChildPath $MarkerFileName
    Set-Content -LiteralPath $markerPath -Value $BrandingVersion -Encoding ASCII -Force

    Write-Output "Install succeeded. Branding assets version '$BrandingVersion' installed to '$BrandingRoot'."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
