<#
.SYNOPSIS
    Clears old print spooler queue files.

.DESCRIPTION
    Intune Remediations remediation script. The script can stop the print
    spooler, remove stale queue files, and restart the spooler after an
    explicit safety switch is enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      No stale print queue files remain
    Exit 1:      Stale print queue files remain or report-only mode is active

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

$ScriptPackageName = 'Clear-Printer-Queue-Safely'
$ScriptName = 'Remediate'

$SpoolFolder = Join-Path -Path $env:SystemRoot -ChildPath 'System32\spool\PRINTERS'
$MinimumPrintJobAgeMinutes = 30
$PrintJobFilePatterns = @('*.spl', '*.shd')
$ClearPrintQueue = $false
$ExitZeroInReportingOnlyMode = $false
$RestartPrintSpooler = $true
$SpoolerServiceName = 'Spooler'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-StalePrintQueueFile {
    $cutoff = (Get-Date).AddMinutes(-[math]::Abs($MinimumPrintJobAgeMinutes))

    if (-not (Test-Path -LiteralPath $SpoolFolder -PathType Container)) {
        return
    }

    foreach ($pattern in $PrintJobFilePatterns) {
        Get-ChildItem -LiteralPath $SpoolFolder -Filter $pattern -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $cutoff }
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $staleFiles = @(Get-StalePrintQueueFile)

    if ($staleFiles.Count -eq 0) {
        Write-Output 'No stale print queue files found.'
        exit 0
    }

    if (-not $ClearPrintQueue) {
        Write-Output "Found $($staleFiles.Count) stale print queue file(s) in reporting-only mode."
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    if ($RestartPrintSpooler) {
        Stop-Service -Name $SpoolerServiceName -Force -ErrorAction Stop
        Write-Log -Message "Stopped service '$SpoolerServiceName'."
    }

    $removedCount = 0
    $failedCount = 0

    foreach ($staleFile in $staleFiles) {
        try {
            Remove-Item -LiteralPath $staleFile.FullName -Force -ErrorAction Stop
            $removedCount++
            Write-Log -Message "Removed print queue file '$($staleFile.FullName)'."
        }
        catch {
            $failedCount++
            Write-Log -Message "Could not remove print queue file '$($staleFile.FullName)'. $($_.Exception.Message)" -Level 'WARN'
        }
    }

    if ($RestartPrintSpooler) {
        Start-Service -Name $SpoolerServiceName -ErrorAction Stop
        Write-Log -Message "Started service '$SpoolerServiceName'."
    }

    Write-Output "Removed $removedCount stale print queue file(s). Failed removals: $failedCount."

    if ($failedCount -eq 0) {
        exit 0
    }

    exit 1
}
catch {
    try {
        Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR'
        if ($RestartPrintSpooler) {
            Start-Service -Name $SpoolerServiceName -ErrorAction SilentlyContinue
        }
    }
    catch {
    }

    Write-Output 'Remediation failed while clearing stale print queue files.'
    exit 1
}
