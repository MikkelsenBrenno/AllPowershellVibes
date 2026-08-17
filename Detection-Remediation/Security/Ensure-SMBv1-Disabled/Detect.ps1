<#
.SYNOPSIS
    Detects whether SMBv1 is disabled.

.DESCRIPTION
    Intune Remediations detection script. The script checks the SMB1 optional
    Windows feature and exits 1 when it appears enabled.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      SMBv1 is disabled or not present
    Exit 1:      SMBv1 is enabled or could not be checked

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
$ScriptName = 'Detect'

$FeatureName = 'SMB1Protocol'
$TreatMissingFeatureAsCompliant = $true

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
    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue

    if ($null -eq $feature) {
        if ($TreatMissingFeatureAsCompliant) {
            Write-Output "Compliant. Feature '$FeatureName' was not found."
            exit 0
        }

        Write-Output "Not compliant. Feature '$FeatureName' was not found."
        exit 1
    }

    if ([string]$feature.State -notmatch '^Enabled') {
        Write-Output "Compliant. Feature '$FeatureName' state is '$($feature.State)'."
        exit 0
    }

    Write-Output "Not compliant. Feature '$FeatureName' state is '$($feature.State)'."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. SMBv1 state could not be validated."
    exit 1
}
