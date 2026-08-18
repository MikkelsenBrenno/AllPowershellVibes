<#
.SYNOPSIS
    Detects large Delivery Optimization cache usage.

.DESCRIPTION
    Intune Remediations detection script. The script estimates Delivery Optimization cache size and exits 1 when it exceeds the configured threshold.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Delivery Optimization cache size is under threshold
    Exit 1:      Delivery Optimization cache size exceeds threshold

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

# Keep these names aligned with the folder and script file.
# Logs are written to Logs\<ScriptPackageName>\<ScriptName>.log.
$ScriptPackageName = 'Clear-Delivery-Optimization-Cache-When-Large'
$ScriptName = 'Detect'

$MaximumCacheSizeMB = 5120
$MaximumCacheItemsToScan = 10000

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

function Get-DeliveryOptimizationCachePath {
    return Join-Path -Path $env:SystemRoot -ChildPath 'ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache'
}

function Get-DeliveryOptimizationCacheState {
    if ($MaximumCacheItemsToScan -lt 1) {
        throw 'MaximumCacheItemsToScan must be 1 or greater.'
    }

    $cachePath = Get-DeliveryOptimizationCachePath
    if (-not (Test-Path -LiteralPath $cachePath)) {
        return [pscustomobject]@{ TotalBytes = [int64]0; ScannedItemCount = 0; ScanLimitExceeded = $false }
    }

    $items = @(Get-ChildItem -LiteralPath $cachePath -Recurse -Force -File -ErrorAction SilentlyContinue |
        Select-Object -First ($MaximumCacheItemsToScan + 1))
    $scanLimitExceeded = ($items.Count -gt $MaximumCacheItemsToScan)
    $measuredItems = @($items | Select-Object -First $MaximumCacheItemsToScan)
    $measure = $measuredItems | Measure-Object -Property Length -Sum

    return [pscustomobject]@{
        TotalBytes = [int64]$measure.Sum
        ScannedItemCount = $measuredItems.Count
        ScanLimitExceeded = $scanLimitExceeded
    }
}

function Convert-BytesToMB {
    param(
        [Parameter(Mandatory = $true)]
        [int64]$Bytes
    )

    return [math]::Round(($Bytes / 1MB), 2)
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. MaximumCacheSizeMB='$MaximumCacheSizeMB'; MaximumItemsToScan='$MaximumCacheItemsToScan'."

    $state = Get-DeliveryOptimizationCacheState
    $sizeMB = Convert-BytesToMB -Bytes $state.TotalBytes
    Write-Log -Message "Delivery Optimization cache estimated size is '$sizeMB' MB; ScannedItems='$($state.ScannedItemCount)'; ScanLimitExceeded='$($state.ScanLimitExceeded)'."

    if (-not $state.ScanLimitExceeded -and $sizeMB -le $MaximumCacheSizeMB) {
        $message = "Compliant. Delivery Optimization cache size is $sizeMB MB."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Delivery Optimization cache size is at least $sizeMB MB. Threshold is $MaximumCacheSizeMB MB; ScanLimitExceeded='$($state.ScanLimitExceeded)'."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "$ScriptName failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Not compliant. Delivery Optimization cache size could not be validated.'
    exit 1
}

