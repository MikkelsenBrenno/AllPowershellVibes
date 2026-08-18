<#
.SYNOPSIS
    Clears old Windows Update download cache files.

.DESCRIPTION
    Intune Remediations remediation script. The script deletes old files from
    the Windows Update download cache only after ClearCacheItems is enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Cache files are absent or removed
    Exit 1:      Cache files remain or removal is disabled

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

$ScriptPackageName = 'Clear-Windows-Update-Download-Cache-Safely'
$ScriptName = 'Remediate'

$CacheRoot = Join-Path -Path $env:SystemRoot -ChildPath 'SoftwareDistribution\Download'
$MinimumCacheItemAgeDays = 14
$MaximumCacheItemsToScan = 10000
$ClearCacheItems = $false
$StopUpdateServicesBeforeClearing = $false
$UpdateServiceNames = @('wuauserv', 'bits')
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

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Test-Path -LiteralPath $CacheRoot -PathType Container)) {
        Write-Output "Cache root '$CacheRoot' does not exist."
        exit 0
    }

    $cutoff = (Get-Date).AddDays(-[math]::Abs($MinimumCacheItemAgeDays))
    $candidates = @(Get-ChildItem -LiteralPath $CacheRoot -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Select-Object -First $MaximumCacheItemsToScan)

    if ($candidates.Count -eq 0) {
        Write-Output 'No old Windows Update download cache files found.'
        exit 0
    }

    if (-not $ClearCacheItems) {
        Write-Output "Found $($candidates.Count) old cache file(s), but ClearCacheItems is disabled."
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    $removedCount = 0
    $failedCount = 0
    $servicesStoppedByScript = @()

    try {
        if ($StopUpdateServicesBeforeClearing) {
            foreach ($serviceName in $UpdateServiceNames) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($null -ne $service -and $service.Status -ne 'Stopped') {
                    Stop-Service -Name $serviceName -Force -ErrorAction Stop
                    $servicesStoppedByScript += $serviceName
                }
            }
        }

        foreach ($candidate in $candidates) {
            try {
                Remove-Item -LiteralPath $candidate.FullName -Force -ErrorAction Stop
                $removedCount++
            }
            catch {
                $failedCount++
                Write-Log -Message "Could not remove '$($candidate.FullName)'. $($_.Exception.Message)" -Level 'WARN'
            }
        }
    }
    finally {
        foreach ($serviceName in $servicesStoppedByScript) {
            try {
                Start-Service -Name $serviceName -ErrorAction Stop
            }
            catch {
                $failedCount++
                Write-Log -Message "Could not restart update service '$serviceName'. $($_.Exception.Message)" -Level 'ERROR'
            }
        }
    }

    $remainingCandidates = @(Get-ChildItem -LiteralPath $CacheRoot -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Select-Object -First 1)

    Write-Output "Removed $removedCount old Windows Update cache file(s). Failures: $failedCount. Remaining matches: $($remainingCandidates.Count)."
    if ($failedCount -eq 0 -and $remainingCandidates.Count -eq 0) { exit 0 }
    exit 1
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed while clearing Windows Update download cache.'
    exit 1
}
