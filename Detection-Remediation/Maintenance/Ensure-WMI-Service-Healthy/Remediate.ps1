<#
.SYNOPSIS
    Repairs Windows Management Instrumentation service state.

.DESCRIPTION
    Intune Remediations remediation script. The script sets the WMI service
    startup type, starts it when configured, and validates the final state.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      WMI service is healthy
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

$ScriptPackageName = 'Ensure-WMI-Service-Healthy'
$ScriptName = 'Remediate'

$ServiceName = 'Winmgmt'
$StartupType = 'Automatic'
$ExpectedStartMode = 'Auto'
$StartServiceAfterChange = $true
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

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        throw "Service '$ServiceName' was not found."
    }

    Set-Service -Name $ServiceName -StartupType $StartupType -ErrorAction Stop

    if ($StartServiceAfterChange -and $service.Status -ne 'Running') {
        Start-Service -Name $ServiceName -ErrorAction Stop
    }

    Start-Sleep -Seconds $ValidationDelaySeconds
    $serviceState = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop

    if ($serviceState.StartMode -ne $ExpectedStartMode -or ($StartServiceAfterChange -and $serviceState.State -ne 'Running')) {
        throw "Service validation failed. StartMode='$($serviceState.StartMode)' State='$($serviceState.State)'."
    }

    Write-Output "Remediation succeeded. Service '$ServiceName' StartMode='$($serviceState.StartMode)' State='$($serviceState.State)'."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation failed for service '$ServiceName'."
    exit 1
}
