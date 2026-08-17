<#
.SYNOPSIS
    Clears Microsoft Store cache folders for the current user.

.DESCRIPTION
    Intune Remediations remediation script. The script removes contents from
    configurable Microsoft Store cache folders. It is report-only by default
    so technicians can verify paths before cleanup.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     User recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation completed or report-only mode completed
    Exit 1:      Remediation failed

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

$ScriptPackageName = 'Clear-Microsoft-Store-Cache-Safely'
$ScriptName = 'Remediate'

$PackagesRoot = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Packages'
$StorePackageFolderPattern = 'Microsoft.WindowsStore_*'
$CacheFolderRelativePaths = @('LocalCache', 'AC')
$ApplyCacheCleanup = $false

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
    Write-Log -Message "Remediation started. ApplyCacheCleanup='$ApplyCacheCleanup'; PackagesRoot='$PackagesRoot'."

    if (-not (Test-Path -LiteralPath $PackagesRoot -PathType Container)) {
        Write-Output "No change needed. Packages root '$PackagesRoot' was not found."
        exit 0
    }

    $storeFolders = @(Get-ChildItem -LiteralPath $PackagesRoot -Directory -Filter $StorePackageFolderPattern -ErrorAction SilentlyContinue)
    $targetPaths = @()

    foreach ($storeFolder in $storeFolders) {
        foreach ($relativePath in $CacheFolderRelativePaths) {
            $cachePath = Join-Path -Path $storeFolder.FullName -ChildPath $relativePath
            if (Test-Path -LiteralPath $cachePath -PathType Container) {
                $targetPaths += $cachePath
            }
        }
    }

    if (-not $ApplyCacheCleanup) {
        Write-Output "Report-only mode. Would clear cache paths: $($targetPaths -join ', ')."
        exit 0
    }

    foreach ($targetPath in $targetPaths) {
        Write-Log -Message "Clearing cache path '$targetPath'."
        Get-ChildItem -LiteralPath $targetPath -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction Stop
    }

    Write-Output 'Remediation completed. Microsoft Store cache paths were cleared.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Microsoft Store cache was not cleared.'
    exit 1
}
