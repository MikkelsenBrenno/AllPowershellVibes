<#
.SYNOPSIS
    Clears old browser cache files.

.DESCRIPTION
    Intune Remediations remediation script. The script scans configurable Edge
    and Chrome cache paths under local user profiles and can remove old cache
    files after an explicit safety switch is enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Browser cache files are absent or removed
    Exit 1:      Matching browser cache files remain

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

$ScriptPackageName = 'Clear-Browser-Cache-Safely'
$ScriptName = 'Remediate'

$ExcludedProfileNames = @('Public', 'Default', 'Default User', 'All Users')
$MinimumCacheItemAgeDays = 7
$MaximumCacheItemsToScan = 10000
$DeleteCacheItems = $false
$ExitZeroInReportingOnlyMode = $false
$BrowserCacheRelativePaths = @(
    'AppData\Local\Microsoft\Edge\User Data\Default\Cache',
    'AppData\Local\Microsoft\Edge\User Data\Default\Code Cache',
    'AppData\Local\Microsoft\Edge\User Data\Default\GPUCache',
    'AppData\Local\Google\Chrome\User Data\Default\Cache',
    'AppData\Local\Google\Chrome\User Data\Default\Code Cache',
    'AppData\Local\Google\Chrome\User Data\Default\GPUCache'
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

function Get-TargetUserProfilePath {
    try {
        $profiles = @(Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop |
            Where-Object { -not $_.Special -and -not [string]::IsNullOrWhiteSpace($_.LocalPath) -and (Test-Path -LiteralPath $_.LocalPath -PathType Container) } |
            Select-Object -ExpandProperty LocalPath -Unique)

        if ($profiles.Count -gt 0) {
            return $profiles
        }
    }
    catch {
        Write-Log -Message "Could not query Win32_UserProfile. Falling back to SystemDrive user profile root. $($_.Exception.Message)" -Level 'WARN'
    }

    $fallbackProfileRoot = Join-Path -Path $env:SystemDrive -ChildPath 'Users'
    if (-not (Test-Path -LiteralPath $fallbackProfileRoot -PathType Container)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $fallbackProfileRoot -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $ExcludedProfileNames -notcontains $_.Name } |
        Select-Object -ExpandProperty FullName)
}

function Get-BrowserCacheCandidate {
    $cutoff = (Get-Date).AddDays(-[math]::Abs($MinimumCacheItemAgeDays))
    $emittedCount = 0

    if ($MaximumCacheItemsToScan -le 0) {
        return
    }

    $profiles = @(Get-TargetUserProfilePath)

    foreach ($profilePath in $profiles) {
        foreach ($relativePath in $BrowserCacheRelativePaths) {
            $cachePath = Join-Path -Path $profilePath -ChildPath $relativePath

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
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    $candidates = @(Get-BrowserCacheCandidate)

    if ($candidates.Count -eq 0) {
        Write-Output 'No matching old browser cache files found.'
        exit 0
    }

    if (-not $DeleteCacheItems) {
        Write-Output "Found $($candidates.Count) old browser cache file(s) in reporting-only mode."
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    $removedCount = 0
    $failedCount = 0

    foreach ($candidate in $candidates) {
        try {
            Remove-Item -LiteralPath $candidate.FullName -Force -ErrorAction Stop
            $removedCount++
            Write-Log -Message "Removed browser cache file '$($candidate.FullName)'."
        }
        catch {
            $failedCount++
            Write-Log -Message "Could not remove browser cache file '$($candidate.FullName)'. $($_.Exception.Message)" -Level 'WARN'
        }
    }

    $remainingCandidates = @(Get-BrowserCacheCandidate | Select-Object -First 1)
    Write-Output "Removed $removedCount old browser cache file(s). Failed removals: $failedCount. Remaining matches: $($remainingCandidates.Count)."

    if ($failedCount -eq 0 -and $remainingCandidates.Count -eq 0) {
        exit 0
    }

    exit 1
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed while clearing old browser cache files.'
    exit 1
}
