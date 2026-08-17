<#
.SYNOPSIS
    Cleans selected temporary folders when disk space is low.

.DESCRIPTION
    Intune Remediations remediation script. The script can remove old files
    from configurable cleanup roots. It is report-only by default so target
    paths can be reviewed first.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Cleanup completed or report-only mode completed
    Exit 1:      Cleanup failed

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

$CleanupRoots = @(
    (Join-Path -Path $env:SystemRoot -ChildPath 'Temp'),
    (Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\WER\ReportArchive'),
    (Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\WER\ReportQueue')
)
$MinimumFileAgeDays = 7
$ApplyCleanup = $false

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Cleanup started. ApplyCleanup='$ApplyCleanup'; MinimumFileAgeDays='$MinimumFileAgeDays'."

    $cutoff = (Get-Date).AddDays(-1 * $MinimumFileAgeDays)
    $targets = @()

    foreach ($root in $CleanupRoots) {
        if (Test-Path -LiteralPath $root -PathType Container) {
            $targets += @(Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $cutoff })
        }
    }

    if (-not $ApplyCleanup) {
        Write-Output "Report-only mode. Would remove '$($targets.Count)' old cleanup files."
        exit 0
    }

    $removedCount = 0
    foreach ($target in $targets) {
        Remove-Item -LiteralPath $target.FullName -Force -ErrorAction SilentlyContinue
        $removedCount++
    }

    Write-Output "Cleanup completed. Removed '$removedCount' files."
    exit 0
}
catch {
    try { Write-Log -Message "Cleanup failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Cleanup failed.'
    exit 1
}
