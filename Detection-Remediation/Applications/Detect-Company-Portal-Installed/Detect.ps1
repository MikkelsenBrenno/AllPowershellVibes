<#
.SYNOPSIS
    Detects whether Company Portal is installed.

.DESCRIPTION
    Intune Remediations detection script. The script checks all-user AppX
    packages and provisioned packages for the configured Company Portal package
    name.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Company Portal is installed or provisioned
    Exit 1:      Company Portal is missing

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

$ScriptPackageName = 'Detect-Company-Portal-Installed'
$ScriptName = 'Detect'

$AppxPackageName = 'Microsoft.CompanyPortal'
$CheckProvisionedPackage = $true

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

    $installedPackage = Get-AppxPackage -AllUsers -Name $AppxPackageName -ErrorAction SilentlyContinue | Select-Object -First 1
    $provisionedPackage = $null

    if ($CheckProvisionedPackage) {
        $provisionedPackage = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq $AppxPackageName } |
            Select-Object -First 1
    }

    if ($null -ne $installedPackage -or $null -ne $provisionedPackage) {
        Write-Output "Compliant. '$AppxPackageName' is installed or provisioned."
        exit 0
    }

    Write-Output "Not compliant. '$AppxPackageName' is missing."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. '$AppxPackageName' could not be validated."
    exit 1
}
