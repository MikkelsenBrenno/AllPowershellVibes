<#
.SYNOPSIS
    Detects BITS service availability.

.DESCRIPTION
    Intune Remediations detection script. The script checks that the Background
    Intelligent Transfer Service exists, is not disabled, and can optionally
    require it to be running.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      BITS service is compliant
    Exit 1:      BITS service is missing, disabled, or stopped

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

$ScriptPackageName = 'Ensure-BITS-Service-Available'
$ScriptName = 'Detect'

$ServiceName = 'BITS'
$RequireRunning = $false
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
    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop

    if ($null -eq $service) {
        Write-Output "Not compliant. Service '$ServiceName' was not found."
        exit 1
    }

    if ($AllowedStartModes -notcontains [string]$service.StartMode) {
        Write-Output "Not compliant. Service '$ServiceName' StartMode='$($service.StartMode)'."
        exit 1
    }

    if ($RequireRunning -and $service.State -ne 'Running') {
        Write-Output "Not compliant. Service '$ServiceName' State='$($service.State)'."
        exit 1
    }

    Write-Output "Compliant. Service '$ServiceName' StartMode='$($service.StartMode)' State='$($service.State)'."
    exit 0
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. BITS service could not be validated."
    exit 1
}
