<#
.SYNOPSIS
    Removes configured built-in AppX packages.

.DESCRIPTION
    Intune Remediations remediation script. The script can remove installed
    and provisioned AppX packages that match configurable package name
    patterns. It is report-only by default.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation completed or report-only mode completed
    Exit 1:      Remediation failed

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

$ScriptPackageName = 'Remove-BuiltIn-Appx-Packages-Template'
$ScriptName = 'Remediate'

$AppxPackageNamePatterns = @(
    'Microsoft.BingWeather',
    'Microsoft.GetHelp'
)
$RemoveInstalledPackages = $true
$RemoveProvisionedPackages = $true
$ApplyAppxRemoval = $false

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Test-PackageNameMatches {
    param([Parameter(Mandatory = $true)][string]$Name)

    foreach ($pattern in $AppxPackageNamePatterns) {
        if ($Name -like $pattern) {
            return $true
        }
    }

    return $false
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. ApplyAppxRemoval='$ApplyAppxRemoval'."

    $installedMatches = @()
    $provisionedMatches = @()

    if ($RemoveInstalledPackages -and (Get-Command -Name Get-AppxPackage -ErrorAction SilentlyContinue)) {
        $installedMatches = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { Test-PackageNameMatches -Name $_.Name })
    }

    if ($RemoveProvisionedPackages -and (Get-Command -Name Get-AppxProvisionedPackage -ErrorAction SilentlyContinue)) {
        $provisionedMatches = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { Test-PackageNameMatches -Name $_.DisplayName })
    }

    if (-not $ApplyAppxRemoval) {
        $names = @($installedMatches.Name + $provisionedMatches.DisplayName | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        Write-Output "Report-only mode. Would remove AppX packages: $($names -join ', ')."
        exit 0
    }

    foreach ($package in $installedMatches) {
        Write-Log -Message "Removing installed AppX package '$($package.PackageFullName)'."
        Remove-AppxPackage -Package $package.PackageFullName -AllUsers -ErrorAction SilentlyContinue
    }

    foreach ($package in $provisionedMatches) {
        Write-Log -Message "Removing provisioned AppX package '$($package.PackageName)'."
        Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction Stop | Out-Null
    }

    Write-Output 'Remediation completed. Configured AppX removal actions finished.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Configured AppX packages were not removed.'
    exit 1
}
