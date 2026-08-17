<#
.SYNOPSIS
    Discovers whether SMBv1 is disabled.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks the SMB1
    optional Windows feature state and returns one compressed JSON object.

.NOTES
    Name:        Discover.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Custom Compliance
    Output:      Compressed JSON

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

$ScriptPackageName = 'Check-SMBv1-State'
$ScriptName = 'Discover'

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

$result = [ordered]@{
    SMBv1Disabled = $false
    SMBv1FeatureState = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue

    if ($null -eq $feature) {
        $result.SMBv1FeatureState = 'NotFound'
        $result.SMBv1Disabled = [bool]$TreatMissingFeatureAsCompliant
    }
    else {
        $result.SMBv1FeatureState = [string]$feature.State
        $result.SMBv1Disabled = ([string]$feature.State -notmatch '^Enabled')
    }

    Write-Log -Message "Discovery completed. FeatureName='$FeatureName'; State='$($result.SMBv1FeatureState)'; Disabled='$($result.SMBv1Disabled)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.SMBv1Disabled = $false
    $result.SMBv1FeatureState = 'Error'
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
