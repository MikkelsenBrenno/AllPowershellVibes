<#
.SYNOPSIS
    Detects old print spooler queue files.

.DESCRIPTION
    Intune Remediations detection script. The script checks the Windows print
    spool folder for old queue files and exits 1 when stale print jobs are
    found.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      No stale print queue files found
    Exit 1:      Stale print queue files found

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
$ScriptName = 'Detect'

$SpoolFolder = Join-Path -Path $env:SystemRoot -ChildPath 'System32\spool\PRINTERS'
$MinimumPrintJobAgeMinutes = 30
$PrintJobFilePatterns = @('*.spl', '*.shd')

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
    $totalBytes = ($staleFiles | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $totalBytes) { $totalBytes = 0 }

    Write-Log -Message "Detection completed. StaleFileCount='$($staleFiles.Count)'; TotalBytes='$totalBytes'; MinimumAgeMinutes='$MinimumPrintJobAgeMinutes'."

    if ($staleFiles.Count -eq 0) {
        Write-Output 'Compliant. No stale print queue files found.'
        exit 0
    }

    Write-Output "Not compliant. Found $($staleFiles.Count) stale print queue file(s), totaling $totalBytes byte(s)."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Print queue state could not be validated.'
    exit 1
}
