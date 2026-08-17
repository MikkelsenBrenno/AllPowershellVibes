<#
.SYNOPSIS
    Clears old Teams and Office cache files.

.DESCRIPTION
    Intune Remediations remediation script. The script scans configurable
    cache paths under local user profiles and can remove old cache files
    after an explicit safety switch is enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Cache files are absent or removed
    Exit 1:      Matching cache files remain

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

$ScriptPackageName = 'Clear-Teams-Office-Cache-Safely'
$ScriptName = 'Remediate'

$UserProfileRoot = 'C:\Users'
$ExcludedProfileNames = @('Public', 'Default', 'Default User', 'All Users')
$MinimumCacheItemAgeDays = 7
$DeleteCacheItems = $false
$ExitZeroInReportingOnlyMode = $false
$CacheRelativePaths = @(
    'AppData\Roaming\Microsoft\Teams\Cache',
    'AppData\Roaming\Microsoft\Teams\Code Cache',
    'AppData\Roaming\Microsoft\Teams\GPUCache',
    'AppData\Local\Microsoft\Office\16.0\OfficeFileCache'
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

    if (-not (Test-Path -LiteralPath $UserProfileRoot -PathType Container)) {
        return
    }

    $profiles = Get-ChildItem -LiteralPath $UserProfileRoot -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $ExcludedProfileNames -notcontains $_.Name }

    foreach ($profile in $profiles) {
        foreach ($relativePath in $CacheRelativePaths) {
            $cachePath = Join-Path -Path $profile.FullName -ChildPath $relativePath

            if (-not (Test-Path -LiteralPath $cachePath -PathType Container)) {
                continue
            }

            Get-ChildItem -LiteralPath $cachePath -File -Recurse -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $cutoff }
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
        Write-Output 'No matching old cache files found.'
        exit 0
    }

    if (-not $DeleteCacheItems) {
        Write-Output "Found $($candidates.Count) old cache file(s) in reporting-only mode."
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    $removedCount = 0
    $failedCount = 0

    foreach ($candidate in $candidates) {
        try {
            Remove-Item -LiteralPath $candidate.FullName -Force -ErrorAction Stop
            $removedCount++
            Write-Log -Message "Removed cache file '$($candidate.FullName)'."
        }
        catch {
            $failedCount++
            Write-Log -Message "Could not remove cache file '$($candidate.FullName)'. $($_.Exception.Message)" -Level 'WARN'
        }
    }

    Write-Output "Removed $removedCount old cache file(s). Failed removals: $failedCount."

    if ($failedCount -eq 0) {
        exit 0
    }

    exit 1
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed while clearing old cache files.'
    exit 1
}
