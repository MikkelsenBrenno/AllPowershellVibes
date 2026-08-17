<#
.SYNOPSIS
    Creates a local support information registry key.

.DESCRIPTION
    Intune platform script example. The script writes configurable support
    information values to a dedicated HKLM registry key.

.NOTES
    Name:        Create-Local-Support-Info-Registry-Key.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Support information was written and validated
    Exit 1:      Support information could not be written

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

$ScriptPackageName = 'Create-Local-Support-Info-Registry-Key'
$ScriptName = 'Create-Local-Support-Info-Registry-Key'

$RegistryPath = 'HKLM:\SOFTWARE\IntuneScriptLibrary\SupportInfo'
$CompanyName = 'Contoso IT'
$SupportUrl = 'https://example.com/support'
$SupportEmail = 'support@example.com'
$SupportPhone = '+1 555 0100'

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
    if (-not (Test-Path -LiteralPath $RegistryPath)) { New-Item -Path $RegistryPath -ItemType Directory -Force | Out-Null }
    $values = @{ CompanyName = $CompanyName; SupportUrl = $SupportUrl; SupportEmail = $SupportEmail; SupportPhone = $SupportPhone }
    foreach ($name in $values.Keys) { New-ItemProperty -Path $RegistryPath -Name $name -Value $values[$name] -PropertyType String -Force | Out-Null }
    $written = Get-ItemProperty -LiteralPath $RegistryPath -ErrorAction Stop
    if ([string]$written.CompanyName -ne $CompanyName) { throw 'Support info validation failed.' }
    Write-Output "Support information written to '$RegistryPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to write support information.'
    exit 1
}
