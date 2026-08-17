<#
.SYNOPSIS
    Starts or restarts the Intune Management Extension service.

.DESCRIPTION
    Intune Remediations remediation script. The script starts the Intune
    Management Extension service and can optionally restart it when it is
    already running.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      IME service is running
    Exit 1:      IME service could not be started

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

$ScriptPackageName = 'Restart-Intune-Management-Extension-Service'
$ScriptName = 'Remediate'

$ServiceName = 'IntuneManagementExtension'
$RestartIfAlreadyRunning = $false
$StartupType = 'Automatic'

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
    Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction Stop
    $service = Get-Service -Name $ServiceName -ErrorAction Stop

    if ($service.Status -eq 'Running' -and $RestartIfAlreadyRunning) {
        Restart-Service -Name $ServiceName -Force -ErrorAction Stop
    }
    elseif ($service.Status -ne 'Running') {
        Start-Service -Name $ServiceName -ErrorAction Stop
    }

    $finalService = Get-Service -Name $ServiceName -ErrorAction Stop
    if ($finalService.Status -ne 'Running') {
        throw "Service '$ServiceName' is '$($finalService.Status)' after remediation."
    }

    Write-Output "Service '$ServiceName' is running."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation failed for service '$ServiceName'."
    exit 1
}
