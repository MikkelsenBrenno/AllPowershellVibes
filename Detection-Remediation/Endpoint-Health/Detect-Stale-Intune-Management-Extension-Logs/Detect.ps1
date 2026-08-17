<#
.SYNOPSIS
    Detects stale Intune Management Extension logs.

.DESCRIPTION
    Intune Remediations detection script. The script checks the newest log in
    the Intune Management Extension log folder and exits 1 when logs are older
    than the configured threshold.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Recent IME log activity exists
    Exit 1:      IME logs are stale or missing

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

$ScriptPackageName = 'Detect-Stale-Intune-Management-Extension-Logs'
$ScriptName = 'Detect'

$ImeLogFolder = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneManagementExtension\Logs'
$MaximumNewestLogAgeDays = 3

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

    if (-not (Test-Path -LiteralPath $ImeLogFolder -PathType Container)) {
        Write-Output "Not compliant. IME log folder '$ImeLogFolder' is missing."
        exit 1
    }

    $newestLog = Get-ChildItem -LiteralPath $ImeLogFolder -Filter '*.log' -File -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -eq $newestLog) {
        Write-Output "Not compliant. No IME log files found in '$ImeLogFolder'."
        exit 1
    }

    $ageDays = ((Get-Date) - $newestLog.LastWriteTime).TotalDays
    Write-Log -Message "NewestLog='$($newestLog.FullName)'; AgeDays='$([math]::Round($ageDays, 2))'."

    if ($ageDays -le $MaximumNewestLogAgeDays) {
        Write-Output "Compliant. Newest IME log is $([math]::Round($ageDays, 2)) day(s) old."
        exit 0
    }

    Write-Output "Not compliant. Newest IME log is $([math]::Round($ageDays, 2)) day(s) old."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. IME log age could not be validated.'
    exit 1
}
