<#
.SYNOPSIS
    Disables SMBv1.

.DESCRIPTION
    Intune Remediations remediation script. The script disables the SMB1
    optional Windows feature only after DisableSmb1 is enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      SMBv1 disabled or reporting-only success enabled
    Exit 1:      SMBv1 remains enabled or remediation is disabled

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

$ScriptPackageName = 'Ensure-SMBv1-Disabled'
$ScriptName = 'Remediate'

$FeatureName = 'SMB1Protocol'
$DisableSmb1 = $false
$NoRestart = $true
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

    if (-not $DisableSmb1) {
        Write-Output "SMBv1 would be disabled, but DisableSmb1 is disabled."
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    Disable-WindowsOptionalFeature -Online -FeatureName $FeatureName -NoRestart:$NoRestart -ErrorAction Stop | Out-Null
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop

    if ([string]$feature.State -match '^Enabled') {
        throw "Feature '$FeatureName' is still '$($feature.State)'."
    }

    Write-Output "SMBv1 feature '$FeatureName' state is '$($feature.State)'. A restart may be required."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation failed while disabling SMBv1."
    exit 1
}
