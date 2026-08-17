<#
.SYNOPSIS
    Detects a local PowerShell module.

.DESCRIPTION
    Win32 app custom detection script template. Intune considers the app
    detected only when this script exits 0 and writes a string to STDOUT.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Detection
    Exit 0:      PowerShell module detected, with STDOUT
    Exit 1:      PowerShell module missing or version mismatch

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

$ScriptPackageName = 'Install-Local-PowerShell-Module-Template'
$ScriptName = 'Detect'

$ModuleName = 'ExampleModule'
$ModuleVersion = '1.0.0'
$ModuleBaseRoot = Join-Path -Path $env:ProgramFiles -ChildPath 'WindowsPowerShell\Modules'
$ModuleManifestFileName = 'ExampleModule.psd1'
$ExpectedModuleFiles = @('ExampleModule.psm1', 'ExampleModule.psd1')

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

    $moduleInstallRoot = Join-Path -Path (Join-Path -Path $ModuleBaseRoot -ChildPath $ModuleName) -ChildPath $ModuleVersion
    if (-not (Test-Path -LiteralPath $moduleInstallRoot -PathType Container)) {
        exit 1
    }

    foreach ($relativePath in $ExpectedModuleFiles) {
        $expectedPath = Join-Path -Path $moduleInstallRoot -ChildPath $relativePath
        if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) {
            exit 1
        }
    }

    $manifestPath = Join-Path -Path $moduleInstallRoot -ChildPath $ModuleManifestFileName
    $manifest = Import-PowerShellDataFile -Path $manifestPath -ErrorAction Stop

    if ([string]$manifest.ModuleVersion -ne $ModuleVersion) {
        exit 1
    }

    Write-Output "Detected. PowerShell module '$ModuleName' version '$ModuleVersion' is installed at '$moduleInstallRoot'."
    exit 0
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    exit 1
}
