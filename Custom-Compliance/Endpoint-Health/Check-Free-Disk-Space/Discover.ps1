<#
.SYNOPSIS
    Discovers free disk space for custom compliance.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks free space
    for a configurable local drive and returns one compressed JSON object.

.NOTES
    Name:        Discover.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Custom Compliance
    Output:      Compressed JSON

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
$ScriptPackageName = 'Check-Free-Disk-Space'
$ScriptName = 'Discover'

# Drive to evaluate. Use the drive letter without a colon.
$DriveLetter = 'C'

# Device is compliant only when both thresholds are met.
$MinimumFreeSpacePercent = 15
$MinimumFreeSpaceGB = 10

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

# =========================
# MAIN
# =========================

$normalizedDriveLetter = ($DriveLetter -replace '[:\\]', '').Trim().Substring(0, 1).ToUpperInvariant()
$deviceId = "${normalizedDriveLetter}:"

$result = [ordered]@{
    DriveLetter = $deviceId
    FreeSpaceCompliant = $false
    FreeSpacePercent = 0
    FreeSpaceGB = 0
    TotalSpaceGB = 0
}

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Discovery started. DriveLetter='$deviceId'; MinimumFreeSpacePercent='$MinimumFreeSpacePercent'; MinimumFreeSpaceGB='$MinimumFreeSpaceGB'."

    $logicalDisk = Get-CimInstance -ClassName 'Win32_LogicalDisk' -Filter "DeviceID='$deviceId'" -ErrorAction Stop

    if ($null -eq $logicalDisk -or [int]$logicalDisk.DriveType -ne 3) {
        throw "Fixed local disk '$deviceId' was not found."
    }

    $freeSpaceGB = [math]::Round(([double]$logicalDisk.FreeSpace / 1GB), 2)
    $totalSpaceGB = [math]::Round(([double]$logicalDisk.Size / 1GB), 2)
    $freeSpacePercent = 0

    if ([double]$logicalDisk.Size -gt 0) {
        $freeSpacePercent = [math]::Round((([double]$logicalDisk.FreeSpace / [double]$logicalDisk.Size) * 100), 0)
    }

    $result.FreeSpaceGB = [int][math]::Floor($freeSpaceGB)
    $result.TotalSpaceGB = [int][math]::Floor($totalSpaceGB)
    $result.FreeSpacePercent = [int]$freeSpacePercent
    $result.FreeSpaceCompliant = (
        $result.FreeSpacePercent -ge $MinimumFreeSpacePercent -and
        $result.FreeSpaceGB -ge $MinimumFreeSpaceGB
    )

    Write-Log -Message "Discovery completed. FreeSpaceGB='$($result.FreeSpaceGB)'; TotalSpaceGB='$($result.TotalSpaceGB)'; FreeSpacePercent='$($result.FreeSpacePercent)'; Compliant='$($result.FreeSpaceCompliant)'."
}
catch {
    try {
        Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    $result.FreeSpaceCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
