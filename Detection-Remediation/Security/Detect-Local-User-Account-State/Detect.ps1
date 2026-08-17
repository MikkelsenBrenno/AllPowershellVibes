<#
.SYNOPSIS
    Detects local user account existence and enabled state.

.DESCRIPTION
    Intune Remediations detection script. The script checks a configurable
    local user account and validates whether it should exist and whether it
    should be enabled or disabled.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Local user account state is compliant
    Exit 1:      Local user account state is not compliant

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

$ScriptPackageName = 'Detect-Local-User-Account-State'
$ScriptName = 'Detect'

$LocalUserName = 'ExampleLocalUser'
$ShouldExist = $false
$ExpectedEnabledState = $false

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
    if (-not (Get-Command -Name Get-LocalUser -ErrorAction SilentlyContinue)) { throw 'Get-LocalUser is not available.' }
    $user = Get-LocalUser -Name $LocalUserName -ErrorAction SilentlyContinue
    if ($null -eq $user) {
        if (-not $ShouldExist) { Write-Output "Compliant. Local user '$LocalUserName' does not exist."; exit 0 }
        Write-Output "Not compliant. Local user '$LocalUserName' does not exist."
        exit 1
    }
    if (-not $ShouldExist) { Write-Output "Not compliant. Local user '$LocalUserName' exists."; exit 1 }
    if ([bool]$user.Enabled -eq $ExpectedEnabledState) { Write-Output "Compliant. Local user '$LocalUserName' enabled state is '$($user.Enabled)'."; exit 0 }
    Write-Output "Not compliant. Local user '$LocalUserName' enabled state is '$($user.Enabled)'."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. Local user '$LocalUserName' could not be validated."
    exit 1
}
