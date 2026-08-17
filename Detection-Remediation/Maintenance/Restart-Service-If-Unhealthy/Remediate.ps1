<#
.SYNOPSIS
    Starts or restarts an unhealthy service.

.DESCRIPTION
    Intune Remediations remediation script. The script starts a stopped
    service or optionally restarts it even when it is already running.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Service is running after remediation
    Exit 1:      Service could not be started or restarted

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

$ScriptPackageName = 'Restart-Service-If-Unhealthy'
$ScriptName = 'Remediate'

$ServiceName = 'Spooler'
$RestartEvenIfRunning = $false
$ValidationDelaySeconds = 5

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
    $service = Get-Service -Name $ServiceName -ErrorAction Stop
    Write-Log -Message "Before remediation: Service '$ServiceName' status is '$($service.Status)'."

    if ($service.Status.ToString() -eq 'Running' -and $RestartEvenIfRunning) {
        Restart-Service -Name $ServiceName -Force -ErrorAction Stop
    }
    elseif ($service.Status.ToString() -ne 'Running') {
        Start-Service -Name $ServiceName -ErrorAction Stop
    }

    Start-Sleep -Seconds $ValidationDelaySeconds
    $service = Get-Service -Name $ServiceName -ErrorAction Stop
    if ($service.Status.ToString() -eq 'Running') { Write-Output "Remediation succeeded. Service '$ServiceName' is running."; exit 0 }
    Write-Output "Remediation failed. Service '$ServiceName' is '$($service.Status)'."
    exit 1
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation failed for service '$ServiceName'."
    exit 1
}
