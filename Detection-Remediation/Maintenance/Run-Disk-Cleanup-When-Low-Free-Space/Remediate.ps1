<#
.SYNOPSIS
    Cleans selected temporary folders when disk space is low.

.DESCRIPTION
    Intune Remediations remediation script. The script can remove old files
    from configurable cleanup roots. It is report-only by default so target
    paths can be reviewed first. It rechecks the same free-space thresholds
    used by detection before returning success.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Disk free space is above configured thresholds
    Exit 1:      Disk remains low or cleanup is disabled

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

$ScriptPackageName = 'Run-Disk-Cleanup-When-Low-Free-Space'
$ScriptName = 'Remediate'

$DriveLetter = $env:SystemDrive.TrimEnd('\')
$MinimumFreePercent = 15
$MinimumFreeGB = 10
$CleanupRoots = @(
    (Join-Path -Path $env:SystemRoot -ChildPath 'Temp'),
    (Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\WER\ReportArchive'),
    (Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\WER\ReportQueue')
)
$MinimumFileAgeDays = 7
$MaximumCleanupItemsToScan = 10000
$ApplyCleanup = $false
$ExitZeroInReportingOnlyMode = $false

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-DiskState {
    $logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID = '$DriveLetter'" -ErrorAction Stop
    if ($null -eq $logicalDisk -or [double]$logicalDisk.Size -le 0) {
        throw "Drive '$DriveLetter' could not be queried."
    }

    $freeGB = [math]::Round(($logicalDisk.FreeSpace / 1GB), 2)
    $freePercent = [math]::Round((($logicalDisk.FreeSpace / $logicalDisk.Size) * 100), 2)
    return [pscustomobject]@{
        FreeGB = $freeGB
        FreePercent = $freePercent
        Compliant = ($freePercent -ge $MinimumFreePercent -and $freeGB -ge $MinimumFreeGB)
    }
}

function Get-CleanupTarget {
    if ($MaximumCleanupItemsToScan -lt 1) {
        throw 'MaximumCleanupItemsToScan must be 1 or greater.'
    }

    $cutoff = (Get-Date).AddDays(-[math]::Abs($MinimumFileAgeDays))
    $emittedCount = 0

    foreach ($root in $CleanupRoots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            continue
        }

        $remaining = $MaximumCleanupItemsToScan - $emittedCount
        if ($remaining -le 0) {
            return
        }

        Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff } |
            Select-Object -First $remaining |
            ForEach-Object {
                $emittedCount++
                $_
            }
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Cleanup started. ApplyCleanup='$ApplyCleanup'; MinimumFileAgeDays='$MinimumFileAgeDays'."

    $beforeState = Get-DiskState
    if ($beforeState.Compliant) {
        Write-Output "No change needed. Drive '$DriveLetter' has '$($beforeState.FreeGB)' GB / '$($beforeState.FreePercent)' percent free."
        exit 0
    }

    $targets = @(Get-CleanupTarget)

    if (-not $ApplyCleanup) {
        Write-Output "Report-only mode. Drive '$DriveLetter' remains low; would remove '$($targets.Count)' old cleanup files."
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    $removedCount = 0
    $failedCount = 0
    foreach ($target in $targets) {
        try {
            Remove-Item -LiteralPath $target.FullName -Force -ErrorAction Stop
            $removedCount++
        }
        catch {
            $failedCount++
            Write-Log -Message "Could not remove '$($target.FullName)'. $($_.Exception.Message)" -Level 'WARN'
        }
    }

    $afterState = Get-DiskState
    if ($failedCount -eq 0 -and $afterState.Compliant) {
        Write-Output "Cleanup succeeded. Removed '$removedCount' files. Drive '$DriveLetter' has '$($afterState.FreeGB)' GB / '$($afterState.FreePercent)' percent free."
        exit 0
    }

    Write-Output "Cleanup incomplete. Removed '$removedCount' files; failures='$failedCount'. Drive '$DriveLetter' has '$($afterState.FreeGB)' GB / '$($afterState.FreePercent)' percent free."
    exit 1
}
catch {
    try { Write-Log -Message "Cleanup failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Cleanup failed.'
    exit 1
}
