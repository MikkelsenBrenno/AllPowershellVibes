<#
.SYNOPSIS
    Cleans old Intune script library logs.

.DESCRIPTION
    Intune platform script example. The script reports or removes log files
    older than the configured age under a configurable log root.

.NOTES
    Name:        Clean-Old-Script-Logs.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Log cleanup completed
    Exit 1:      Log cleanup failed

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

$ScriptPackageName = 'Clean-Old-Script-Logs'
$ScriptName = 'Clean-Old-Script-Logs'

$TargetLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$FileNamePatterns = @('*.log', '*.txt')
$OlderThanDays = 30
$ApplyCleanup = $false
$MaximumFilesToProcess = 500

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

    if ($OlderThanDays -lt 1) {
        throw 'OlderThanDays must be 1 or greater.'
    }

    if (-not (Test-Path -LiteralPath $TargetLogRoot -PathType Container)) {
        Write-Output "Log root '$TargetLogRoot' does not exist. Nothing to clean."
        exit 0
    }

    $cutoff = (Get-Date).AddDays(-1 * $OlderThanDays)
    $candidates = foreach ($pattern in $FileNamePatterns) {
        Get-ChildItem -LiteralPath $TargetLogRoot -Filter $pattern -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt $cutoff }
    }

    $candidates = @($candidates | Sort-Object LastWriteTime | Select-Object -First $MaximumFilesToProcess)
    foreach ($file in $candidates) {
        Write-Log -Message "Candidate '$($file.FullName)' LastWriteTime='$($file.LastWriteTime)'."
        if ($ApplyCleanup) {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
        }
    }

    $mode = if ($ApplyCleanup) { 'removed' } else { 'reported' }
    Write-Output "Log cleanup completed. Files ${mode}: $($candidates.Count)."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to clean old script logs.'
    exit 1
}
