<#
.SYNOPSIS
    Detects large Recycle Bin usage.

.DESCRIPTION
    Intune Remediations detection script. The script estimates Recycle Bin size across fixed drives and exits 1 when it exceeds the configured threshold.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     User recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Recycle Bin size is under threshold
    Exit 1:      Recycle Bin size exceeds threshold

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
$ScriptPackageName = 'Clear-Recycle-Bin-When-Large'
$ScriptName = 'Detect'

$MaximumRecycleBinSizeMB = 2048
$MaximumRecycleBinItemsToScan = 10000

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
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

function Get-RecycleBinState {
    if ($MaximumRecycleBinItemsToScan -lt 1) {
        throw 'MaximumRecycleBinItemsToScan must be 1 or greater.'
    }

    $drives = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue)
    $recyclePaths = @($drives | ForEach-Object {
        $path = Join-Path -Path $_.DeviceID -ChildPath '$Recycle.Bin'
        if (Test-Path -LiteralPath $path -PathType Container) { $path }
    })

    $items = @()
    if ($recyclePaths.Count -gt 0) {
        $items = @(Get-ChildItem -LiteralPath $recyclePaths -Recurse -Force -File -ErrorAction SilentlyContinue |
            Select-Object -First ($MaximumRecycleBinItemsToScan + 1))
    }

    $scanLimitExceeded = ($items.Count -gt $MaximumRecycleBinItemsToScan)
    $measuredItems = @($items | Select-Object -First $MaximumRecycleBinItemsToScan)
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
    Write-Log -Message "Detection started. MaximumRecycleBinSizeMB='$MaximumRecycleBinSizeMB'; MaximumItemsToScan='$MaximumRecycleBinItemsToScan'."

    $state = Get-RecycleBinState
    $sizeMB = Convert-BytesToMB -Bytes $state.TotalBytes
    Write-Log -Message "Recycle Bin estimated size is '$sizeMB' MB; ScannedItems='$($state.ScannedItemCount)'; ScanLimitExceeded='$($state.ScanLimitExceeded)'."

    if (-not $state.ScanLimitExceeded -and $sizeMB -le $MaximumRecycleBinSizeMB) {
        $message = "Compliant. Recycle Bin estimated size is $sizeMB MB."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Recycle Bin estimated size is at least $sizeMB MB. Threshold is $MaximumRecycleBinSizeMB MB; ScanLimitExceeded='$($state.ScanLimitExceeded)'."
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

    Write-Output 'Not compliant. Recycle Bin size could not be validated.'
    exit 1
}

