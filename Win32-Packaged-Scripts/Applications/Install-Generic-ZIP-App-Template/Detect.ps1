<#
.SYNOPSIS
    Detects whether a generic ZIP-based application payload is installed.

.DESCRIPTION
    Win32 app detection script. The script checks a configurable install
    folder and marker version.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      ZIP application detected
    Exit 1:      ZIP application missing or version mismatch

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
$ScriptName = 'Detect'

$InstallRoot = Join-Path -Path $env:ProgramFiles -ChildPath 'Contoso\ExampleZipApp'
$MarkerFileName = 'install.version'
$ExpectedVersion = '1.0.0'
$RequiredFileRelativePaths = @()

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

    $markerPath = Join-Path -Path $InstallRoot -ChildPath $MarkerFileName

    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        Write-Output "Not detected. Install root '$InstallRoot' is missing."
        exit 1
    }

    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        Write-Output "Not detected. Marker file '$markerPath' is missing."
        exit 1
    }

    $installedVersion = (Get-Content -LiteralPath $markerPath -Raw).Trim()
    if ($installedVersion -ne $ExpectedVersion) {
        Write-Output "Not detected. Expected version '$ExpectedVersion' but found '$installedVersion'."
        exit 1
    }

    foreach ($relativePath in $RequiredFileRelativePaths) {
        $requiredPath = Join-Path -Path $InstallRoot -ChildPath $relativePath
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            Write-Output "Not detected. Required file '$requiredPath' is missing."
            exit 1
        }
    }

    Write-Output "Detected. ZIP app version '$ExpectedVersion' is installed."
    exit 0
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not detected. ZIP app detection failed.'
    exit 1
}
