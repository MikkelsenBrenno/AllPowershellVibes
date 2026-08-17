<#
.SYNOPSIS
    Disables PowerShell 2.0 optional features.

.DESCRIPTION
    Intune Remediations remediation script. The script disables configurable
    Windows optional features after ApplyPolicy is enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      PowerShell 2.0 feature is disabled or disable pending
    Exit 1:      PowerShell 2.0 feature remains enabled

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

$ScriptPackageName = 'Ensure-PowerShellV2-Disabled'
$ScriptName = 'Remediate'

$FeatureNames = @('MicrosoftWindowsPowerShellV2', 'MicrosoftWindowsPowerShellV2Root')
$ValidationFeatureName = 'MicrosoftWindowsPowerShellV2'
$CompliantStates = @('Disabled', 'DisablePending')
$ApplyPolicy = $false
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

    if (-not $ApplyPolicy) {
        Write-Output 'PowerShell 2.0 optional features would be disabled, but ApplyPolicy is disabled.'
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    $restartNeeded = $false

    foreach ($featureName in $FeatureNames) {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $featureName -ErrorAction SilentlyContinue
        if ($null -eq $feature) {
            Write-Log -Message "Feature '$featureName' was not found. Skipping." -Level 'WARN'
            continue
        }

        if ($CompliantStates -contains [string]$feature.State) {
            Write-Log -Message "Feature '$featureName' already in state '$($feature.State)'."
            continue
        }

        $result = Disable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart -ErrorAction Stop
        if ($null -ne $result -and [bool]$result.RestartNeeded) {
            $restartNeeded = $true
        }
    }

    $validationFeature = Get-WindowsOptionalFeature -Online -FeatureName $ValidationFeatureName -ErrorAction Stop
    $validationState = [string]$validationFeature.State

    if ($CompliantStates -notcontains $validationState) {
        throw "Feature '$ValidationFeatureName' State='$validationState' after remediation."
    }

    Write-Output "PowerShell 2.0 feature state is '$validationState'. RestartNeeded='$restartNeeded'."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed while disabling PowerShell 2.0 optional features.'
    exit 1
}
