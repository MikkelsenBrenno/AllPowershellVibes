<#
.SYNOPSIS
    Detects old Windows Update download cache files.

.DESCRIPTION
    Intune Remediations detection script. The script scans the Windows Update
    download cache and exits 1 when old files are found.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      No old cache files found
    Exit 1:      Old cache files found

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
$ScriptName = 'Detect'

$CacheRoot = Join-Path -Path $env:SystemRoot -ChildPath 'SoftwareDistribution\Download'
$MinimumCacheItemAgeDays = 14
$MaximumCacheItemsToScan = 10000

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
        Write-Output "Compliant. Cache root '$CacheRoot' does not exist."
        exit 0
    }

    $cutoff = (Get-Date).AddDays(-[math]::Abs($MinimumCacheItemAgeDays))
    $candidates = @(Get-ChildItem -LiteralPath $CacheRoot -File -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Select-Object -First $MaximumCacheItemsToScan)
    $totalBytes = ($candidates | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $totalBytes) { $totalBytes = 0 }

    Write-Log -Message "Detection completed. CandidateCount='$($candidates.Count)'; TotalBytes='$totalBytes'; MaximumItemsToScan='$MaximumCacheItemsToScan'."

    if ($candidates.Count -eq 0) {
        Write-Output 'Compliant. No old Windows Update download cache files found.'
        exit 0
    }

    Write-Output "Not compliant. Found $($candidates.Count) old Windows Update cache file(s), totaling $totalBytes byte(s)."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Windows Update download cache could not be validated.'
    exit 1
}
