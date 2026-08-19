<#
.SYNOPSIS
    Configures Windows Time service startup state.

.DESCRIPTION
    Intune Remediations remediation script. The script sets the Windows Time
    service startup type and can optionally start the service.

.NOTES
    Name:        Remediate.ps1
    Version:     1.1.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Windows Time service startup state is compliant
    Exit 1:      Windows Time service startup state remains noncompliant

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

$ScriptPackageName = 'Ensure-Windows-Time-Service-Automatic'
$ScriptName = 'Remediate'

$ServiceName = 'W32Time'
$StartupType = 'Automatic'
$ExpectedStartMode = 'Auto'
$RequireRunning = $false

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

    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
    if ($null -eq $service) {
        throw "Service '$ServiceName' was not found."
    }

    if ([string]$service.StartMode -ne $ExpectedStartMode) {
        Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction Stop
    }

    if ($RequireRunning -and [string]$service.State -ne 'Running') {
        Start-Service -Name $ServiceName -ErrorAction Stop
    }

    $updatedService = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
    $startModeOk = ([string]$updatedService.StartMode -eq $ExpectedStartMode)
    $runningOk = (-not $RequireRunning -or [string]$updatedService.State -eq 'Running')
    if (-not $startModeOk -or -not $runningOk) {
        throw "Service '$ServiceName' validation failed. StartMode='$($updatedService.StartMode)' State='$($updatedService.State)'."
    }

    Write-Output "Windows Time service '$ServiceName' StartMode='$($updatedService.StartMode)' State='$($updatedService.State)'."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation failed for Windows Time service '$ServiceName'."
    exit 1
}
