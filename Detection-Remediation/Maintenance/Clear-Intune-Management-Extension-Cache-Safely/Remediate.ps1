<#
.SYNOPSIS
    Clears old Intune Management Extension cache files.

.DESCRIPTION
    Intune Remediations remediation script. The script removes old IME cache
    files only after the explicit ClearCacheItems safety switch is enabled.

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

$ScriptPackageName = 'Clear-Intune-Management-Extension-Cache-Safely'
$ScriptName = 'Remediate'

$MinimumCacheItemAgeDays = 14
$MaximumCacheItemsToScan = 10000
$ClearCacheItems = $false
$ExitZeroInReportingOnlyMode = $false
$CachePaths = @(
    'C:\Windows\IMECache',
    'C:\Program Files (x86)\Microsoft Intune Management Extension\Content\Incoming',
    'C:\Program Files (x86)\Microsoft Intune Management Extension\Content\Staging'
)

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-CacheCandidate {
    $cutoff = (Get-Date).AddDays(-[math]::Abs($MinimumCacheItemAgeDays))
    $emittedCount = 0

    if ($MaximumCacheItemsToScan -le 0) {
        return
    }

    foreach ($cachePath in $CachePaths) {
        if (-not (Test-Path -LiteralPath $cachePath -PathType Container)) {
            continue
        }

        $remaining = $MaximumCacheItemsToScan - $emittedCount
        if ($remaining -le 0) {
            return
        }

        Get-ChildItem -LiteralPath $cachePath -File -Recurse -Force -ErrorAction SilentlyContinue |
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
    $candidates = @(Get-CacheCandidate)

    if ($candidates.Count -eq 0) {
        Write-Output 'No old IME cache files found.'
        exit 0
    }

    if (-not $ClearCacheItems) {
        Write-Output "Found $($candidates.Count) old IME cache file(s) in reporting-only mode."
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    $removedCount = 0
    $failedCount = 0

    foreach ($candidate in $candidates) {
        try {
            Remove-Item -LiteralPath $candidate.FullName -Force -ErrorAction Stop
            $removedCount++
            Write-Log -Message "Removed IME cache file '$($candidate.FullName)'."
        }
        catch {
            $failedCount++
            Write-Log -Message "Could not remove IME cache file '$($candidate.FullName)'. $($_.Exception.Message)" -Level 'WARN'
        }
    }

    $remainingCandidates = @(Get-CacheCandidate | Select-Object -First 1)
    Write-Output "Removed $removedCount old IME cache file(s). Failed removals: $failedCount. Remaining matches: $($remainingCandidates.Count)."
    if ($failedCount -eq 0 -and $remainingCandidates.Count -eq 0) { exit 0 }
    exit 1
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed while clearing IME cache files.'
    exit 1
}
