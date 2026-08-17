<#
.SYNOPSIS
    Installs a local PowerShell module.

.DESCRIPTION
    Win32 app install script template. The script copies a packaged PowerShell
    module folder into Program Files and validates expected module files.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      PowerShell module installed
    Exit 1:      PowerShell module install failed

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
$ScriptName = 'Install'

$SourceModuleFolderName = 'ExampleModule'
$ModuleName = 'ExampleModule'
$ModuleVersion = '1.0.0'
$ModuleBaseRoot = Join-Path -Path $env:ProgramFiles -ChildPath 'WindowsPowerShell\Modules'
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

function Test-ExpectedModuleFilePresent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleInstallRoot
    )

    foreach ($relativePath in $ExpectedModuleFiles) {
        $expectedPath = Join-Path -Path $ModuleInstallRoot -ChildPath $relativePath
        if (-not (Test-Path -LiteralPath $expectedPath -PathType Leaf)) {
            throw "Expected module file '$expectedPath' was not found."
        }
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $sourceModuleRoot = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Module') -ChildPath $SourceModuleFolderName
    $moduleRoot = Join-Path -Path $ModuleBaseRoot -ChildPath $ModuleName
    $moduleInstallRoot = Join-Path -Path $moduleRoot -ChildPath $ModuleVersion

    if (-not (Test-Path -LiteralPath $sourceModuleRoot -PathType Container)) {
        throw "Source module folder '$sourceModuleRoot' was not found."
    }

    if (-not (Test-Path -LiteralPath $moduleInstallRoot -PathType Container)) {
        New-Item -Path $moduleInstallRoot -ItemType Directory -Force | Out-Null
    }

    Copy-Item -Path (Join-Path -Path $sourceModuleRoot -ChildPath '*') -Destination $moduleInstallRoot -Recurse -Force
    Test-ExpectedModuleFilePresent -ModuleInstallRoot $moduleInstallRoot

    Write-Output "Install succeeded. PowerShell module '$ModuleName' version '$ModuleVersion' installed to '$moduleInstallRoot'."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
