<#
.SYNOPSIS
    Detects whether Remote Registry service is disabled.

.DESCRIPTION
    Intune Remediations detection script. The script checks the Remote
    Registry service startup mode and can optionally require it to be stopped.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remote Registry service is compliant
    Exit 1:      Remote Registry service is missing or noncompliant

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
$ScriptName = 'Detect'

$ServiceName = 'RemoteRegistry'
$ExpectedStartMode = 'Disabled'
$RequireStopped = $true

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
        Write-Output "Not compliant. Service '$ServiceName' was not found."
        exit 1
    }

    if ([string]$service.StartMode -ne $ExpectedStartMode) {
        Write-Output "Not compliant. Service '$ServiceName' StartMode='$($service.StartMode)'."
        exit 1
    }

    if ($RequireStopped -and [string]$service.State -ne 'Stopped') {
        Write-Output "Not compliant. Service '$ServiceName' State='$($service.State)'."
        exit 1
    }

    Write-Output "Compliant. Service '$ServiceName' StartMode='$($service.StartMode)' State='$($service.State)'."
    exit 0
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Remote Registry service could not be validated.'
    exit 1
}
