<#
.SYNOPSIS
    Detects old Intune Management Extension cache files.

.DESCRIPTION
    Intune Remediations detection script. The script scans configurable IME
    cache paths and exits 1 when old cache files are found.

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

$ScriptPackageName = 'Clear-Intune-Management-Extension-Cache-Safely'
$ScriptName = 'Detect'

$MinimumCacheItemAgeDays = 14
$MaximumCacheItemsToScan = 10000
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
    $totalBytes = ($candidates | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $totalBytes) { $totalBytes = 0 }

    Write-Log -Message "Detection completed. CandidateCount='$($candidates.Count)'; TotalBytes='$totalBytes'; MaximumItemsToScan='$MaximumCacheItemsToScan'."

    if ($candidates.Count -eq 0) {
        Write-Output 'Compliant. No old IME cache files found.'
        exit 0
    }

    Write-Output "Not compliant. Found $($candidates.Count) old IME cache file(s), totaling $totalBytes byte(s)."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. IME cache could not be validated.'
    exit 1
}
