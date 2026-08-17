<#
.SYNOPSIS
    Clears Recycle Bin contents when enabled.

.DESCRIPTION
    Intune Remediations remediation script. The script clears Recycle Bin contents only when the safety toggle is enabled and validates the final estimated size.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     User recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Recycle Bin is below threshold after cleanup
    Exit 1:      Recycle Bin remains noncompliant or cleanup is disabled

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
$ScriptName = 'Remediate'

$MaximumRecycleBinSizeMB = 2048
$MaximumRecycleBinItemsToScan = 10000
$ClearRecycleBin = $false
$ExitZeroInReportingOnlyMode = $false
$ValidationDelaySeconds = 3

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
    Write-Log -Message "Remediation started. ClearRecycleBin='$ClearRecycleBin'; MaximumRecycleBinSizeMB='$MaximumRecycleBinSizeMB'; MaximumItemsToScan='$MaximumRecycleBinItemsToScan'."

    $beforeState = Get-RecycleBinState
    $beforeMB = Convert-BytesToMB -Bytes $beforeState.TotalBytes
    Write-Log -Message "Recycle Bin estimated size before remediation is '$beforeMB' MB."

    if (-not $beforeState.ScanLimitExceeded -and $beforeMB -le $MaximumRecycleBinSizeMB) {
        Write-Output "No change needed. Recycle Bin estimated size is $beforeMB MB."
        exit 0
    }

    if (-not $ClearRecycleBin) {
        $message = 'Report-only mode. Set $ClearRecycleBin to $true to empty Recycle Bin contents.'
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    if (-not (Get-Command -Name Clear-RecycleBin -ErrorAction SilentlyContinue)) {
        throw 'Clear-RecycleBin is not available on this device.'
    }

    Clear-RecycleBin -Force -ErrorAction Stop
    Start-Sleep -Seconds $ValidationDelaySeconds

    $afterState = Get-RecycleBinState
    $afterMB = Convert-BytesToMB -Bytes $afterState.TotalBytes
    if (-not $afterState.ScanLimitExceeded -and $afterMB -le $MaximumRecycleBinSizeMB) {
        $message = "Remediation succeeded. Recycle Bin estimated size is $afterMB MB."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. Recycle Bin estimated size is at least $afterMB MB; ScanLimitExceeded='$($afterState.ScanLimitExceeded)'."
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

    Write-Output 'Remediation failed for Recycle Bin cleanup.'
    exit 1
}

