<#
.SYNOPSIS
    Detects stale local user profiles.

.DESCRIPTION
    Intune Remediations detection script. The script checks local user
    profiles and exits 1 when non-special profiles have not been used within
    the configured age threshold.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      No stale profiles found
    Exit 1:      Stale profiles found

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

$ScriptPackageName = 'Detect-Stale-User-Profiles'
$ScriptName = 'Detect'

$StaleProfileAgeDays = 90
$IgnoreSpecialProfiles = $true
$IgnoreLoadedProfiles = $true

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log {
    param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO')
    Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8
}
function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}
function Get-ProfileLastUseTime {
    param([Parameter(Mandatory = $true)][object]$Profile)
    if ([string]::IsNullOrWhiteSpace([string]$Profile.LastUseTime)) { return $null }
    return [System.Management.ManagementDateTimeConverter]::ToDateTime($Profile.LastUseTime)
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    $cutoff = (Get-Date).AddDays(-$StaleProfileAgeDays)
    Write-Log -Message "Detection started. StaleProfileAgeDays='$StaleProfileAgeDays'; Cutoff='$cutoff'."

    $profiles = @(Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop)
    $staleProfiles = New-Object System.Collections.Generic.List[object]

    foreach ($profile in $profiles) {
        if ($IgnoreSpecialProfiles -and [bool]$profile.Special) { continue }
        if ($IgnoreLoadedProfiles -and [bool]$profile.Loaded) { continue }

        $lastUseTime = Get-ProfileLastUseTime -Profile $profile
        if ($null -eq $lastUseTime) { continue }

        Write-Log -Message "Profile='$($profile.LocalPath)'; LastUseTime='$lastUseTime'; Loaded='$($profile.Loaded)'."
        if ($lastUseTime -lt $cutoff) { $staleProfiles.Add($profile) }
    }

    if ($staleProfiles.Count -eq 0) {
        Write-Output 'Compliant. No stale user profiles found.'
        exit 0
    }

    Write-Output "Not compliant. Stale user profiles found: $($staleProfiles.Count)."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Stale profile detection could not complete.'
    exit 1
}
