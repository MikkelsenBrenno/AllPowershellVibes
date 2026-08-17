<#
.SYNOPSIS
    Discovers OneDrive Known Folder Move registry state.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks configurable
    OneDrive Known Folder Move policy values and returns one compressed JSON
    object.

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

$ScriptPackageName = 'Check-OneDrive-KFM-State'
$ScriptName = 'Discover'

$OneDrivePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive'
$ExpectedTenantId = ''
$RequireSilentAccountConfig = $true
$RequireKfmOptIn = $false
$KfmOptInValueName = 'KFMSilentOptIn'
$SilentAccountConfigValueName = 'SilentAccountConfig'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-RegistryValue {
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
    OneDriveKfmStateCompliant = $false
    PolicyPathExists = $false
    ExpectedTenantId = $ExpectedTenantId
    KfmSilentOptIn = ''
    SilentAccountConfig = $null
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $policy = Get-ItemProperty -LiteralPath $OneDrivePolicyPath -ErrorAction SilentlyContinue
    $result.PolicyPathExists = ($null -ne $policy)

    if ($null -ne $policy) {
        $result.KfmSilentOptIn = [string](Get-RegistryValue -Item $policy -Name $KfmOptInValueName)
        $silentConfig = Get-RegistryValue -Item $policy -Name $SilentAccountConfigValueName

        if ($null -ne $silentConfig) {
            $result.SilentAccountConfig = [int]$silentConfig
        }
    }

    $tenantCompliant = ([string]::IsNullOrWhiteSpace($ExpectedTenantId) -or $result.KfmSilentOptIn -eq $ExpectedTenantId)
    $kfmCompliant = (-not $RequireKfmOptIn -or -not [string]::IsNullOrWhiteSpace($result.KfmSilentOptIn))
    $silentConfigCompliant = (-not $RequireSilentAccountConfig -or $result.SilentAccountConfig -eq 1)

    $result.OneDriveKfmStateCompliant = ($result.PolicyPathExists -and $tenantCompliant -and $kfmCompliant -and $silentConfigCompliant)

    Write-Log -Message "Discovery completed. PolicyPathExists='$($result.PolicyPathExists)'; KfmSilentOptIn='$($result.KfmSilentOptIn)'; SilentAccountConfig='$($result.SilentAccountConfig)'; Compliant='$($result.OneDriveKfmStateCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.OneDriveKfmStateCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
