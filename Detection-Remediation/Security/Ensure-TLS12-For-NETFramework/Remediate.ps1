<#
.SYNOPSIS
    Enables .NET Framework TLS 1.2 related registry values.

.DESCRIPTION
    Intune Remediations remediation script. The script creates or updates
    strong crypto and system default TLS values under the configured .NET
    Framework registry paths.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      TLS registry values were applied
    Exit 1:      TLS registry values could not be applied

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

$ScriptPackageName = 'Ensure-TLS12-For-NETFramework'
$ScriptName = 'Remediate'

$ApplyRegistryChanges = $false
$RegistryTargets = @(
    @{
        Path = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
        Values = @('SchUseStrongCrypto', 'SystemDefaultTlsVersions')
    },
    @{
        Path = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'
        Values = @('SchUseStrongCrypto', 'SystemDefaultTlsVersions')
    }
)
$TargetValue = 1

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
    Write-Log -Message "Remediation started. ApplyRegistryChanges='$ApplyRegistryChanges'."

    foreach ($target in $RegistryTargets) {
        foreach ($valueName in $target.Values) {
            Write-Log -Message "Target value. Path='$($target.Path)'; Name='$valueName'; Value='$TargetValue'."

            if ($ApplyRegistryChanges) {
                if (-not (Test-Path -LiteralPath $target.Path)) {
                    New-Item -Path $target.Path -Force | Out-Null
                }

                New-ItemProperty -LiteralPath $target.Path -Name $valueName -PropertyType DWord -Value $TargetValue -Force | Out-Null
            }
        }
    }

    if (-not $ApplyRegistryChanges) {
        Write-Output 'Report-only mode. Set ApplyRegistryChanges to true after pilot testing.'
        exit 0
    }

    Write-Output '.NET Framework TLS registry values were applied.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output '.NET Framework TLS registry values were not applied.'
    exit 1
}
