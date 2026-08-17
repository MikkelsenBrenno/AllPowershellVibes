<#
.SYNOPSIS
    Clears Recycle Bin contents when enabled.

.DESCRIPTION
    Intune Remediations remediation script. The script clears Recycle Bin contents only when the safety toggle is enabled and validates the final estimated size.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Recycle Bin cleanup completed or reported
    Exit 1:      Recycle Bin cleanup failed

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
$ClearRecycleBin = $false
$ValidationDelaySeconds = 3

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

function Get-RecycleBinSizeBytes {
    $totalBytes = [int64]0
    $drives = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue)

    foreach ($drive in $drives) {
        $recyclePath = Join-Path -Path $drive.DeviceID -ChildPath '$Recycle.Bin'
        if (-not (Test-Path -LiteralPath $recyclePath)) {
            continue
        }

        $items = Get-ChildItem -LiteralPath $recyclePath -Recurse -Force -File -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            $totalBytes += [int64]$item.Length
        }
    }

    return $totalBytes
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
    Write-Log -Message "Remediation started. ClearRecycleBin='$ClearRecycleBin'; MaximumRecycleBinSizeMB='$MaximumRecycleBinSizeMB'."

    $beforeMB = Convert-BytesToMB -Bytes (Get-RecycleBinSizeBytes)
    Write-Log -Message "Recycle Bin estimated size before remediation is '$beforeMB' MB."

    if (-not $ClearRecycleBin) {
        $message = 'Report-only mode. Set $ClearRecycleBin to $true to empty Recycle Bin contents.'
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message
        exit 0
    }

    if (-not (Get-Command -Name Clear-RecycleBin -ErrorAction SilentlyContinue)) {
        throw 'Clear-RecycleBin is not available on this device.'
    }

    Clear-RecycleBin -Force -ErrorAction Stop
    Start-Sleep -Seconds $ValidationDelaySeconds

    $afterMB = Convert-BytesToMB -Bytes (Get-RecycleBinSizeBytes)
    if ($afterMB -le $MaximumRecycleBinSizeMB) {
        $message = "Remediation succeeded. Recycle Bin estimated size is $afterMB MB."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. Recycle Bin estimated size is $afterMB MB."
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

