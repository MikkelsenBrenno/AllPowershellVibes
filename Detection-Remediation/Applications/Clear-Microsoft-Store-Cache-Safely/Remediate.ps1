<#
.SYNOPSIS
    Clears Microsoft Store cache folders for the current user.

.DESCRIPTION
    Intune Remediations remediation script. The script removes contents from
    configurable Microsoft Store cache folders. It is report-only by default
    so technicians can verify paths before cleanup. The script returns success
    only after the same cache-size condition used by detection is compliant.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     User recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Store cache is below threshold after remediation
    Exit 1:      Store cache remains noncompliant or cleanup is disabled

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
$MaximumCacheSizeMB = 500
$MaximumCacheItemsToScan = 10000
$ApplyCacheCleanup = $false
$ExitZeroInReportingOnlyMode = $false

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-StoreCacheState {
    if ($MaximumCacheItemsToScan -lt 1) {
        throw 'MaximumCacheItemsToScan must be 1 or greater.'
    }

    $cachePaths = @()
    if (Test-Path -LiteralPath $PackagesRoot -PathType Container) {
        $storeFolders = @(Get-ChildItem -LiteralPath $PackagesRoot -Directory -Filter $StorePackageFolderPattern -ErrorAction SilentlyContinue)
        foreach ($storeFolder in $storeFolders) {
            foreach ($relativePath in $CacheFolderRelativePaths) {
                $cachePath = Join-Path -Path $storeFolder.FullName -ChildPath $relativePath
                if (Test-Path -LiteralPath $cachePath -PathType Container) {
                    $cachePaths += $cachePath
                }
            }
        }
    }

    $items = @()
    if ($cachePaths.Count -gt 0) {
        $items = @(Get-ChildItem -LiteralPath $cachePaths -Recurse -Force -File -ErrorAction SilentlyContinue |
            Select-Object -First ($MaximumCacheItemsToScan + 1))
    }

    $scanLimitExceeded = ($items.Count -gt $MaximumCacheItemsToScan)
    $measuredItems = @($items | Select-Object -First $MaximumCacheItemsToScan)
    $measure = $measuredItems | Measure-Object -Property Length -Sum

    return [pscustomobject]@{
        CachePaths = $cachePaths
        TotalBytes = [int64]$measure.Sum
        ScannedItemCount = $measuredItems.Count
        ScanLimitExceeded = $scanLimitExceeded
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. ApplyCacheCleanup='$ApplyCacheCleanup'; PackagesRoot='$PackagesRoot'."

    $beforeState = Get-StoreCacheState
    $beforeMB = [math]::Round(($beforeState.TotalBytes / 1MB), 2)
    if (-not $beforeState.ScanLimitExceeded -and $beforeMB -le $MaximumCacheSizeMB) {
        Write-Output "No change needed. Microsoft Store cache is '$beforeMB' MB."
        exit 0
    }

    if (-not $ApplyCacheCleanup) {
        Write-Output "Report-only mode. Microsoft Store cache remains noncompliant. Would clear: $($beforeState.CachePaths -join ', ')."
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    foreach ($targetPath in $beforeState.CachePaths) {
        Write-Log -Message "Clearing cache path '$targetPath'."
        Get-ChildItem -LiteralPath $targetPath -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction Stop
    }

    $afterState = Get-StoreCacheState
    $afterMB = [math]::Round(($afterState.TotalBytes / 1MB), 2)
    if (-not $afterState.ScanLimitExceeded -and $afterMB -le $MaximumCacheSizeMB) {
        Write-Output "Remediation succeeded. Microsoft Store cache is '$afterMB' MB."
        exit 0
    }

    Write-Output "Remediation incomplete. Microsoft Store cache is at least '$afterMB' MB; ScanLimitExceeded='$($afterState.ScanLimitExceeded)'."
    exit 1
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Microsoft Store cache was not cleared.'
    exit 1
}
