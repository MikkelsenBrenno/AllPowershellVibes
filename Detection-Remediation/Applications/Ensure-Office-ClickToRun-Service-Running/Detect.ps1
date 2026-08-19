<#
.SYNOPSIS
    Detects Microsoft Office Click-to-Run service health.

.DESCRIPTION
    Intune Remediations detection script. The script checks whether the Office
    Click-to-Run service exists, has the expected startup type, and is running
    when required.

.NOTES
    Name:        Detect.ps1
    Version:     1.1.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Office Click-to-Run service is healthy
    Exit 1:      Office Click-to-Run service is missing or unhealthy

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
$ScriptName = 'Detect'

$ServiceName = 'ClickToRunSvc'
$ExpectedStartMode = 'Auto'
$RequireRunning = $true

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

    Write-Log -Message "Service '$ServiceName' StartMode='$($service.StartMode)' State='$($service.State)'."
    $startModeOk = ([string]$service.StartMode -eq $ExpectedStartMode)
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
