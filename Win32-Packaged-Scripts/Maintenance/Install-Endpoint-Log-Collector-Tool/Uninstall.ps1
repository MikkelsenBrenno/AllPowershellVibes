<#
.SYNOPSIS
    Uninstalls the endpoint log collector helper script.

.DESCRIPTION
    Win32 app uninstall script. The script removes the installed collector
    folder and leaves collected log bundles untouched unless configured.

.NOTES
    Name:        Uninstall.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Collector uninstalled
    Exit 1:      Collector uninstall failed

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

$ScriptPackageName = 'Install-Endpoint-Log-Collector-Tool'
$ScriptName = 'Uninstall'

$InstallRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Tools\EndpointLogCollector'
$CollectedLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\CollectedLogs'
$RemoveCollectedLogBundles = $false

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

    if (Test-Path -LiteralPath $InstallRoot -PathType Container) {
        Remove-Item -LiteralPath $InstallRoot -Recurse -Force
        Write-Log -Message "Removed install root '$InstallRoot'."
    }

    if ($RemoveCollectedLogBundles -and (Test-Path -LiteralPath $CollectedLogRoot -PathType Container)) {
        Remove-Item -LiteralPath $CollectedLogRoot -Recurse -Force
        Write-Log -Message "Removed collected log bundles '$CollectedLogRoot'."
    }

    Write-Output 'Uninstall succeeded. Endpoint log collector was removed.'
    exit 0
}
catch {
    try { Write-Log -Message "Uninstall failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Uninstall failed.'
    exit 1
}
