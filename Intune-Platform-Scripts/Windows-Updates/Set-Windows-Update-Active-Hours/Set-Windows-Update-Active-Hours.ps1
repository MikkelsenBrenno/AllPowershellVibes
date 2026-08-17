<#
.SYNOPSIS
    Configures Windows Update active hours through policy registry values.

.DESCRIPTION
    Intune platform script example. The script writes documented Windows
    Update policy registry values for active hours and validates them.

.NOTES
    Name:        Set-Windows-Update-Active-Hours.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Active hours values were configured
    Exit 1:      Active hours values could not be configured

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

$ScriptPackageName = 'Set-Windows-Update-Active-Hours'
$ScriptName = 'Set-Windows-Update-Active-Hours'

$WindowsUpdatePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$ActiveHoursStart = 8
$ActiveHoursEnd = 17
$EnableActiveHours = $true

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
    Write-Log -Message "Script started. ActiveHoursStart='$ActiveHoursStart'; ActiveHoursEnd='$ActiveHoursEnd'; EnableActiveHours='$EnableActiveHours'."
    foreach ($hour in @($ActiveHoursStart, $ActiveHoursEnd)) { if ($hour -lt 0 -or $hour -gt 23) { throw "Active hour '$hour' is invalid. Use 0 through 23." } }
    if (-not (Test-Path -LiteralPath $WindowsUpdatePolicyPath)) { New-Item -Path $WindowsUpdatePolicyPath -ItemType Directory -Force | Out-Null }
    New-ItemProperty -Path $WindowsUpdatePolicyPath -Name 'SetActiveHours' -Value ([int]$EnableActiveHours) -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $WindowsUpdatePolicyPath -Name 'ActiveHoursStart' -Value $ActiveHoursStart -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $WindowsUpdatePolicyPath -Name 'ActiveHoursEnd' -Value $ActiveHoursEnd -PropertyType DWord -Force | Out-Null
    $policy = Get-ItemProperty -LiteralPath $WindowsUpdatePolicyPath -ErrorAction Stop
    if ([int]$policy.ActiveHoursStart -ne $ActiveHoursStart -or [int]$policy.ActiveHoursEnd -ne $ActiveHoursEnd) { throw 'Active hours validation failed.' }
    Write-Output "Windows Update active hours configured: $ActiveHoursStart-$ActiveHoursEnd."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to configure Windows Update active hours.'
    exit 1
}
