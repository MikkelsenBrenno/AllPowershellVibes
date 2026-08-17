<#
.SYNOPSIS
    Reports or removes stale local user profiles.

.DESCRIPTION
    Intune Remediations remediation script. Removal is disabled by default
    so technicians can review profile paths before enabling deletion.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      No stale profiles remain, or reporting-only mode is enabled
    Exit 1:      Stale profiles remain or deletion failed

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
$ScriptName = 'Remediate'

$StaleProfileAgeDays = 90
$IgnoreSpecialProfiles = $true
$IgnoreLoadedProfiles = $true
$DeleteStaleProfiles = $false
$ExitZeroInReportingOnlyMode = $false

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
function Get-StaleProfiles {
    $cutoff = (Get-Date).AddDays(-$StaleProfileAgeDays)
    $staleProfiles = New-Object System.Collections.Generic.List[object]
    foreach ($profile in @(Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop)) {
        if ($IgnoreSpecialProfiles -and [bool]$profile.Special) { continue }
        if ($IgnoreLoadedProfiles -and [bool]$profile.Loaded) { continue }
        $lastUseTime = Get-ProfileLastUseTime -Profile $profile
        if ($null -ne $lastUseTime -and $lastUseTime -lt $cutoff) { $staleProfiles.Add($profile) }
    }
    return @($staleProfiles)
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. StaleProfileAgeDays='$StaleProfileAgeDays'; DeleteStaleProfiles='$DeleteStaleProfiles'."

    $staleProfiles = @(Get-StaleProfiles)
    foreach ($profile in $staleProfiles) { Write-Log -Message "Stale profile: '$($profile.LocalPath)'." -Level 'WARN' }

    if ($staleProfiles.Count -eq 0) {
        Write-Output 'No stale profiles found.'
        exit 0
    }

    if (-not $DeleteStaleProfiles) {
        Write-Output "Stale profiles remain in reporting-only mode: $($staleProfiles.Count)."
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    foreach ($profile in $staleProfiles) {
        Write-Log -Message "Removing stale profile '$($profile.LocalPath)'."
        Remove-CimInstance -InputObject $profile -ErrorAction Stop
    }

    $remainingProfiles = @(Get-StaleProfiles)
    if ($remainingProfiles.Count -eq 0) {
        Write-Output 'Stale profile cleanup completed.'
        exit 0
    }

    Write-Output "Stale profiles remain: $($remainingProfiles.Count)."
    exit 1
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Stale profile remediation failed.'
    exit 1
}
