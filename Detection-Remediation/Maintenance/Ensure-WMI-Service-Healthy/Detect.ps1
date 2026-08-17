<#
.SYNOPSIS
    Detects Windows Management Instrumentation service health.

.DESCRIPTION
    Intune Remediations detection script. The script checks whether the WMI
    service exists, is not disabled, and is running when required.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      WMI service is healthy
    Exit 1:      WMI service is missing or unhealthy

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

$ScriptPackageName = 'Ensure-WMI-Service-Healthy'
$ScriptName = 'Detect'

$ServiceName = 'Winmgmt'
$RequireRunning = $true
$AllowedStartModes = @('Auto', 'Manual')

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

    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        Write-Output "Not compliant. Service '$ServiceName' was not found."
        exit 1
    }

    $startModeOk = ($AllowedStartModes -contains [string]$service.StartMode)
    $runningOk = (-not $RequireRunning -or [string]$service.State -eq 'Running')

    if ($startModeOk -and $runningOk) {
        Write-Output "Compliant. Service '$ServiceName' StartMode='$($service.StartMode)' State='$($service.State)'."
        exit 0
    }

    Write-Output "Not compliant. Service '$ServiceName' StartMode='$($service.StartMode)' State='$($service.State)'."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. Service '$ServiceName' could not be validated."
    exit 1
}
