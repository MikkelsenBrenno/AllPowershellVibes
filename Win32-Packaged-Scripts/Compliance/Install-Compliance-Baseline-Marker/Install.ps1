<#
.SYNOPSIS
    Installs a local compliance baseline marker.

.DESCRIPTION
    Win32 app install script example. The script writes configurable registry
    values that can be used as a local baseline marker and validates them.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Compliance marker installed
    Exit 1:      Compliance marker install failed

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

$ScriptPackageName = 'Install-Compliance-Baseline-Marker'
$ScriptName = 'Install'

$MarkerRegistryPath = 'HKLM:\SOFTWARE\Microsoft\IntuneScriptLibrary\Win32ComplianceMarker'
$BaselineName = 'Example Baseline'
$BaselineVersion = '1.0.0'
$InstallTimestampValueName = 'InstalledAt'

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

    if (-not (Test-Path -LiteralPath $MarkerRegistryPath)) {
        New-Item -Path $MarkerRegistryPath -Force | Out-Null
    }

    New-ItemProperty -Path $MarkerRegistryPath -Name 'BaselineName' -Value $BaselineName -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $MarkerRegistryPath -Name 'BaselineVersion' -Value $BaselineVersion -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $MarkerRegistryPath -Name $InstallTimestampValueName -Value (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') -PropertyType String -Force | Out-Null

    $marker = Get-ItemProperty -LiteralPath $MarkerRegistryPath -ErrorAction Stop
    if ([string]$marker.BaselineName -ne $BaselineName -or [string]$marker.BaselineVersion -ne $BaselineVersion) {
        throw 'Compliance marker validation failed.'
    }

    Write-Output "Install succeeded. Compliance marker '$BaselineName' version '$BaselineVersion' installed."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
