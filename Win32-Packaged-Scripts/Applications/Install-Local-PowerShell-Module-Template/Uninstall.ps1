<#
.SYNOPSIS
    Uninstalls a local PowerShell module.

.DESCRIPTION
    Win32 app uninstall script template. The script removes a specific module
    version folder and can remove the parent module folder when it is empty.

.NOTES
    Name:        Uninstall.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      PowerShell module removed or already absent
    Exit 1:      PowerShell module uninstall failed

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
$ScriptName = 'Uninstall'

$ModuleName = 'ExampleModule'
$ModuleVersion = '1.0.0'
$ModuleBaseRoot = Join-Path -Path $env:ProgramFiles -ChildPath 'WindowsPowerShell\Modules'
$RemoveParentModuleFolderIfEmpty = $true

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

    $moduleRoot = Join-Path -Path $ModuleBaseRoot -ChildPath $ModuleName
    $moduleInstallRoot = Join-Path -Path $moduleRoot -ChildPath $ModuleVersion

    if (Test-Path -LiteralPath $moduleInstallRoot -PathType Container) {
        Remove-Item -LiteralPath $moduleInstallRoot -Recurse -Force
        Write-Log -Message "Removed module version folder '$moduleInstallRoot'."
    }

    if ($RemoveParentModuleFolderIfEmpty -and (Test-Path -LiteralPath $moduleRoot -PathType Container)) {
        $remainingItems = @(Get-ChildItem -LiteralPath $moduleRoot -Force -ErrorAction SilentlyContinue)
        if ($remainingItems.Count -eq 0) {
            Remove-Item -LiteralPath $moduleRoot -Force
            Write-Log -Message "Removed empty module parent folder '$moduleRoot'."
        }
    }

    Write-Output "Uninstall succeeded. PowerShell module '$ModuleName' version '$ModuleVersion' is absent."
    exit 0
}
catch {
    try { Write-Log -Message "Uninstall failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Uninstall failed.'
    exit 1
}
