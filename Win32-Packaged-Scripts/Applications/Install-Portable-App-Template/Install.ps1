<#
.SYNOPSIS
    Installs a portable application folder.

.DESCRIPTION
    Win32 app install script template. The script copies a configurable payload
    folder to ProgramData and writes a version marker for detection.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Portable app installed
    Exit 1:      Portable app install failed

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

$ScriptPackageName = 'Install-Portable-App-Template'
$ScriptName = 'Install'

$PayloadFolderName = 'Payload'
$InstallRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\PortableApps\ExamplePortableApp'
$PackageVersion = '1.0.0'
$MarkerFileName = 'portable-app-version.txt'

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

    $payloadPath = Join-Path -Path $PSScriptRoot -ChildPath $PayloadFolderName
    if (-not (Test-Path -LiteralPath $payloadPath -PathType Container)) {
        throw "Payload folder '$payloadPath' was not found."
    }

    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        New-Item -Path $InstallRoot -ItemType Directory -Force | Out-Null
    }

    Copy-Item -LiteralPath (Join-Path -Path $payloadPath -ChildPath '*') -Destination $InstallRoot -Recurse -Force
    Set-Content -LiteralPath (Join-Path -Path $InstallRoot -ChildPath $MarkerFileName) -Value $PackageVersion -Encoding ASCII -Force

    Write-Output "Install succeeded. Portable app version '$PackageVersion' installed to '$InstallRoot'."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
