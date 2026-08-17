<#
.SYNOPSIS
    Detects Autopilot Profile package marker.

.DESCRIPTION
    Detects Autopilot Profile as a reusable Win32 script package.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Detection
    Exit 0:      Package detected with STDOUT
    Exit 1:      Package not detected

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

$ScriptPackageName = 'Install-Autopilot-Profile-Package'
$ScriptName = 'Detect'

$ManagedItemName = 'Autopilot Profile'
$ExpectedPackageVersion = '1.0.0'
$InstallRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Win32Packages\MDM-Enrollment\Install-Autopilot-Profile-Package'
$MarkerFileName = 'install-autopilot-profile-package.state'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"
$script:LogAvailable = $false

function Initialize-Log {
    try {
        if (-not (Test-Path -LiteralPath $LogRoot -PathType Container)) {
            New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
        }

        $script:LogAvailable = $true
    }
    catch {
        $script:LogAvailable = $false
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    if (-not $script:LogAvailable) {
        return
    }

    try {
        Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8
    }
    catch {
        $script:LogAvailable = $false
    }
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $markerPath = Join-Path -Path $InstallRoot -ChildPath $MarkerFileName
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        exit 1
    }

    $actualVersion = (Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop).Trim()
    if ($actualVersion -eq $ExpectedPackageVersion) {
        Write-Output "Detected. '$ManagedItemName' package version '$ExpectedPackageVersion' is installed."
        exit 0
    }

    exit 1
}
catch {
    try { Write-Log -Message "Detection local error. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    exit 1
}
