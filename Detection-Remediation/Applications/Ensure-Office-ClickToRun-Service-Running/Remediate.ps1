<#
.SYNOPSIS
    Repairs Microsoft Office Click-to-Run service state.

.DESCRIPTION
    Intune Remediations remediation script. The script sets the Office
    Click-to-Run service startup type and optionally starts the service.

.NOTES
    Name:        Remediate.ps1
    Version:     1.1.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Office Click-to-Run service is healthy
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

$ScriptPackageName = 'Ensure-Office-ClickToRun-Service-Running'
$ScriptName = 'Remediate'

$ServiceName = 'ClickToRunSvc'
$StartupType = 'Automatic'
$ExpectedStartMode = 'Auto'
$RequireRunning = $true
$ValidationDelaySeconds = 3

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
    Write-Log -Message "Remediation started. ServiceName='$ServiceName'; StartupType='$StartupType'; ExpectedStartMode='$ExpectedStartMode'; RequireRunning='$RequireRunning'."

    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        throw "Service '$ServiceName' was not found."
    }

    Write-Log -Message "Current service state StartMode='$($service.StartMode)' State='$($service.State)'."
    if ([string]$service.StartMode -ne $ExpectedStartMode) {
        Write-Log -Message "Setting service '$ServiceName' startup type to '$StartupType'."
        Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction Stop
    }

    if ($RequireRunning -and [string]$service.State -ne 'Running') {
        Write-Log -Message "Starting service '$ServiceName'."
        Start-Service -Name $ServiceName -ErrorAction Stop
    }

    Start-Sleep -Seconds $ValidationDelaySeconds
    $serviceState = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop

    $startModeOk = ([string]$serviceState.StartMode -eq $ExpectedStartMode)
    $runningOk = (-not $RequireRunning -or [string]$serviceState.State -eq 'Running')
    if (-not $startModeOk -or -not $runningOk) {
        throw "Service validation failed. StartMode='$($serviceState.StartMode)' State='$($serviceState.State)'."
    }

    $message = "Remediation succeeded. Service '$ServiceName' StartMode='$($serviceState.StartMode)' State='$($serviceState.State)'."
    Write-Log -Message $message
    Write-Output $message
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation failed for service '$ServiceName'."
    exit 1
}
