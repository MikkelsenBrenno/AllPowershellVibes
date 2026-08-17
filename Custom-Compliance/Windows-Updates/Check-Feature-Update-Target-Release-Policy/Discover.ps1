<#
.SYNOPSIS
    Discovers Windows feature update target release policy.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks configurable
    Windows Update target release registry policy values and returns one
    compressed JSON object.

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

$ScriptPackageName = 'Check-Feature-Update-Target-Release-Policy'
$ScriptName = 'Discover'

$WindowsUpdatePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$ExpectedTargetReleaseVersionInfo = 'REPLACE_WITH_TARGET_VERSION'
$ExpectedProductVersion = 'Windows 11'
$RequireTargetReleaseVersionEnabled = $true

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-RegistryValueOrNull {
    param(
        [object]$Item,
        [string]$Name
    )

    if ($null -eq $Item -or $Item.PSObject.Properties.Name -notcontains $Name) {
        return $null
    }

    return $Item.$Name
}

# =========================
# MAIN
# =========================

$result = [ordered]@{
    FeatureUpdateTargetReleaseCompliant = $false
    PolicyPathExists = $false
    ExpectedTargetReleaseVersionInfo = $ExpectedTargetReleaseVersionInfo
    ExpectedProductVersion = $ExpectedProductVersion
    TargetReleaseVersion = $null
    TargetReleaseVersionInfo = ''
    ProductVersion = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $policy = Get-ItemProperty -LiteralPath $WindowsUpdatePolicyPath -ErrorAction SilentlyContinue
    $result.PolicyPathExists = ($null -ne $policy)

    if ($null -ne $policy) {
        $targetReleaseVersion = Get-RegistryValueOrNull -Item $policy -Name 'TargetReleaseVersion'
        if ($null -ne $targetReleaseVersion) {
            $result.TargetReleaseVersion = [int]$targetReleaseVersion
        }

        $result.TargetReleaseVersionInfo = [string](Get-RegistryValueOrNull -Item $policy -Name 'TargetReleaseVersionInfo')
        $result.ProductVersion = [string](Get-RegistryValueOrNull -Item $policy -Name 'ProductVersion')
    }

    $enabledCompliant = (-not $RequireTargetReleaseVersionEnabled -or $result.TargetReleaseVersion -eq 1)
    $targetCompliant = ($result.TargetReleaseVersionInfo -eq $ExpectedTargetReleaseVersionInfo)
    $productCompliant = ([string]::IsNullOrWhiteSpace($ExpectedProductVersion) -or $result.ProductVersion -eq $ExpectedProductVersion)
    $result.FeatureUpdateTargetReleaseCompliant = ($result.PolicyPathExists -and $enabledCompliant -and $targetCompliant -and $productCompliant)

    Write-Log -Message "Discovery completed. TargetReleaseVersionInfo='$($result.TargetReleaseVersionInfo)'; ProductVersion='$($result.ProductVersion)'; Compliant='$($result.FeatureUpdateTargetReleaseCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.FeatureUpdateTargetReleaseCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
