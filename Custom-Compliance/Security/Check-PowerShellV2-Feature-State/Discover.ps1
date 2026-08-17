<#
.SYNOPSIS
    Discovers PowerShell 2.0 optional feature state.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks a configurable
    Windows optional feature and returns one compressed JSON object.

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

$ScriptPackageName = 'Check-PowerShellV2-Feature-State'
$ScriptName = 'Discover'

$FeatureName = 'MicrosoftWindowsPowerShellV2'
$ExpectedState = 'Disabled'

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
    PowerShellV2FeatureCompliant = $false
    FeatureName = $FeatureName
    FeatureExists = $false
    FeatureState = ''
    ExpectedState = $ExpectedState
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction Stop
    if ($null -eq $feature) {
        throw "Feature '$FeatureName' was not found."
    }

    $result.FeatureExists = $true
    $result.FeatureState = [string]$feature.State
    $result.PowerShellV2FeatureCompliant = ($result.FeatureState -eq $ExpectedState)

    Write-Log -Message "Discovery completed. Feature='$FeatureName'; State='$($result.FeatureState)'; Expected='$ExpectedState'; Compliant='$($result.PowerShellV2FeatureCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.PowerShellV2FeatureCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
