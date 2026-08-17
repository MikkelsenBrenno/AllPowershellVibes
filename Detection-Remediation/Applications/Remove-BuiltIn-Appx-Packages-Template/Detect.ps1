<#
.SYNOPSIS
    Detects configured built-in AppX packages.

.DESCRIPTION
    Intune Remediations detection script. The script searches installed AppX
    packages and provisioned AppX packages for configurable package name
    patterns.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Configured AppX packages were not found
    Exit 1:      One or more configured AppX packages were found

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
$ScriptName = 'Detect'

$AppxPackageNamePatterns = @(
    'Microsoft.BingWeather',
    'Microsoft.GetHelp'
)
$CheckInstalledPackages = $true
$CheckProvisionedPackages = $true

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

    $matches = @()

    if ($CheckInstalledPackages -and (Get-Command -Name Get-AppxPackage -ErrorAction SilentlyContinue)) {
        $matches += @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { Test-PackageNameMatches -Name $_.Name } | ForEach-Object { "Installed:$($_.Name)" })
    }

    if ($CheckProvisionedPackages -and (Get-Command -Name Get-AppxProvisionedPackage -ErrorAction SilentlyContinue)) {
        $matches += @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { Test-PackageNameMatches -Name $_.DisplayName } | ForEach-Object { "Provisioned:$($_.DisplayName)" })
    }

    if ($matches.Count -eq 0) {
        $message = 'Compliant. Configured AppX packages were not found.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Configured AppX packages found: $($matches -join ', ')."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Configured AppX packages could not be validated.'
    exit 1
}
