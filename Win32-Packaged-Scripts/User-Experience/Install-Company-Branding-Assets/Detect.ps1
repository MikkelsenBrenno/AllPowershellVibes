<#
.SYNOPSIS
    Detects company branding assets.

.DESCRIPTION
    Win32 app detection script example. The script checks that configurable
    branding files exist and that the version marker matches.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Detection
    Exit 0:      Branding assets detected, with STDOUT
    Exit 1:      Branding assets missing or incorrect

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
$ScriptName = 'Detect'

$BrandingRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Branding'
$ExpectedBrandingVersion = '1.0.0'
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
    $missingItems = New-Object System.Collections.Generic.List[string]

    foreach ($assetFileName in $AssetFileNames) {
        $assetPath = Join-Path -Path $BrandingRoot -ChildPath $assetFileName
        if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
            $missingItems.Add($assetFileName)
        }
    }

    $markerPath = Join-Path -Path $BrandingRoot -ChildPath $MarkerFileName
    $actualVersion = ''

    if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
        $actualVersion = (Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop).Trim()
    }

    if ($missingItems.Count -eq 0 -and $actualVersion -eq $ExpectedBrandingVersion) {
        Write-Output "Detected. Branding assets version '$actualVersion' are installed."
        exit 0
    }

    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    exit 1
}
