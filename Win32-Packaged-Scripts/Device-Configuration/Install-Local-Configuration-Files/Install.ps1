<#
.SYNOPSIS
    Installs local configuration files.

.DESCRIPTION
    Win32 app install script template. The script copies a payload folder from
    the package to a configurable ProgramData path and writes a versioned
    marker file for reliable Intune detection.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Configuration files installed
    Exit 1:      Configuration file install failed

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

$ScriptPackageName = 'Install-Local-Configuration-Files'
$ScriptName = 'Install'

$SourcePayloadFolderName = 'Payload'
$DestinationRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ConfigurationFiles\ExampleConfig'
$PackageVersion = '1.0.0'
$DetectionMarkerFileName = 'install-marker.json'
$ExpectedFileRelativePaths = @('ExampleConfig.json')

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Test-ExpectedFilePresent {
    foreach ($relativePath in $ExpectedFileRelativePaths) {
        $expectedPath = Join-Path -Path $DestinationRoot -ChildPath $relativePath
        if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) {
            throw "Expected file '$expectedPath' was not found."
        }
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $sourcePayloadRoot = Join-Path -Path $PSScriptRoot -ChildPath $SourcePayloadFolderName
    if (-not (Test-Path -LiteralPath $sourcePayloadRoot -PathType Container)) {
        throw "Source payload folder '$sourcePayloadRoot' was not found."
    }

    if (-not (Test-Path -LiteralPath $DestinationRoot -PathType Container)) {
        New-Item -Path $DestinationRoot -ItemType Directory -Force | Out-Null
    }

    Copy-Item -Path (Join-Path -Path $sourcePayloadRoot -ChildPath '*') -Destination $DestinationRoot -Recurse -Force
    Test-ExpectedFilePresent

    $markerPath = Join-Path -Path $DestinationRoot -ChildPath $DetectionMarkerFileName
    $marker = [ordered]@{
        PackageName = $ScriptPackageName
        PackageVersion = $PackageVersion
        InstalledAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        InstalledBy = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        ExpectedFileRelativePaths = $ExpectedFileRelativePaths
    }

    $marker | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $markerPath -Encoding UTF8

    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        throw "Detection marker '$markerPath' was not created."
    }

    Write-Output "Install succeeded. Configuration files version '$PackageVersion' installed to '$DestinationRoot'."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
