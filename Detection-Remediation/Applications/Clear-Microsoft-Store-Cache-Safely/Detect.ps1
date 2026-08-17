<#
.SYNOPSIS
    Detects whether Microsoft Store cache exceeds a configured size.

.DESCRIPTION
    Intune Remediations detection script. The script checks Microsoft Store
    package cache folders in the current user profile and reports
    noncompliance when the total size exceeds the configured threshold.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     User recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Store cache is below threshold or not present
    Exit 1:      Store cache exceeds threshold

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
$ScriptName = 'Detect'

$PackagesRoot = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Packages'
$StorePackageFolderPattern = 'Microsoft.WindowsStore_*'
$CacheFolderRelativePaths = @('LocalCache', 'AC')
$MaximumCacheSizeMB = 500

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-FolderSizeBytes {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return 0
    }

    $measure = Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum
    return [int64]($measure.Sum)
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Test-Path -LiteralPath $PackagesRoot -PathType Container)) {
        Write-Output "Compliant. Packages root '$PackagesRoot' was not found."
        exit 0
    }

    $storeFolders = @(Get-ChildItem -LiteralPath $PackagesRoot -Directory -Filter $StorePackageFolderPattern -ErrorAction SilentlyContinue)
    $totalBytes = 0

    foreach ($storeFolder in $storeFolders) {
        foreach ($relativePath in $CacheFolderRelativePaths) {
            $cachePath = Join-Path -Path $storeFolder.FullName -ChildPath $relativePath
            $totalBytes += Get-FolderSizeBytes -Path $cachePath
        }
    }

    $totalMB = [math]::Round(($totalBytes / 1MB), 2)
    if ($totalMB -le $MaximumCacheSizeMB) {
        $message = "Compliant. Microsoft Store cache is '$totalMB' MB."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Microsoft Store cache is '$totalMB' MB; Threshold='$MaximumCacheSizeMB' MB."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Microsoft Store cache could not be validated.'
    exit 1
}
