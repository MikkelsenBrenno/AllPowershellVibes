<#
.SYNOPSIS
    Clears Delivery Optimization cache when enabled.

.DESCRIPTION
    Intune Remediations remediation script. The script uses Delete-DeliveryOptimizationCache and validates the final estimated cache size.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Delivery Optimization cache cleanup completed
    Exit 1:      Delivery Optimization cache cleanup failed

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
$ScriptName = 'Remediate'

$MaximumCacheSizeMB = 5120
$MaximumCacheItemsToScan = 10000
$ClearDeliveryOptimizationCache = $true
$ExitZeroInReportingOnlyMode = $false
$ValidationDelaySeconds = 5

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
    Write-Log -Message "Remediation started. ClearDeliveryOptimizationCache='$ClearDeliveryOptimizationCache'; MaximumItemsToScan='$MaximumCacheItemsToScan'."

    $beforeState = Get-DeliveryOptimizationCacheState
    $beforeMB = Convert-BytesToMB -Bytes $beforeState.TotalBytes
    Write-Log -Message "Delivery Optimization cache before remediation is '$beforeMB' MB."

    if (-not $beforeState.ScanLimitExceeded -and $beforeMB -le $MaximumCacheSizeMB) {
        Write-Output "No change needed. Delivery Optimization cache size is $beforeMB MB."
        exit 0
    }

    if (-not $ClearDeliveryOptimizationCache) {
        $message = 'Report-only mode. Set $ClearDeliveryOptimizationCache to $true to clear Delivery Optimization cache.'
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    if (Get-Command -Name Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) {
        Delete-DeliveryOptimizationCache -Force -ErrorAction Stop | Out-Null
    }
    else {
        throw 'Delete-DeliveryOptimizationCache is not available on this device.'
    }

    Start-Sleep -Seconds $ValidationDelaySeconds
    $afterState = Get-DeliveryOptimizationCacheState
    $afterMB = Convert-BytesToMB -Bytes $afterState.TotalBytes

    if (-not $afterState.ScanLimitExceeded -and $afterMB -le $MaximumCacheSizeMB) {
        $message = "Remediation succeeded. Delivery Optimization cache size is $afterMB MB."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. Delivery Optimization cache size is at least $afterMB MB; ScanLimitExceeded='$($afterState.ScanLimitExceeded)'."
    Write-Log -Message $message -Level 'ERROR'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "$ScriptName failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Remediation failed for Delivery Optimization cache cleanup.'
    exit 1
}

