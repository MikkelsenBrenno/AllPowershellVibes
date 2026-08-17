<#
.SYNOPSIS
    Disables Remote Registry service.

.DESCRIPTION
    Intune Remediations remediation script. The script stops and disables the
    Remote Registry service after ApplyPolicy is enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remote Registry service is compliant
    Exit 1:      Remote Registry service remains noncompliant

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

$ScriptPackageName = 'Ensure-Remote-Registry-Service-Disabled'
$ScriptName = 'Remediate'

$ServiceName = 'RemoteRegistry'
$StartupType = 'Disabled'
$StopServiceAfterChange = $true
$ApplyPolicy = $false
$ExitZeroInReportingOnlyMode = $false

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

    if (-not $ApplyPolicy) {
        Write-Output 'Remote Registry service would be disabled, but ApplyPolicy is disabled.'
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
    if ($null -eq $service) {
        throw "Service '$ServiceName' was not found."
    }

    if ($StopServiceAfterChange) {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
    }

    Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction Stop

    $updatedService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
    if ([string]$updatedService.StartMode -ne 'Disabled') {
        throw "Service '$ServiceName' StartMode is '$($updatedService.StartMode)' after remediation."
    }

    Write-Output "Remote Registry service '$ServiceName' StartMode='$($updatedService.StartMode)' State='$($updatedService.State)'."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation failed for Remote Registry service '$ServiceName'."
    exit 1
}
