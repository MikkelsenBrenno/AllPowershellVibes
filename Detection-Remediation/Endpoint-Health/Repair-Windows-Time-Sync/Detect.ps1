<#
.SYNOPSIS
    Detects Windows Time service and sync state.

.DESCRIPTION
    Intune Remediations detection script. The script checks that the Windows
    Time service is running and optionally treats Local CMOS Clock as
    noncompliant.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Windows Time appears healthy
    Exit 1:      Windows Time needs attention

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

$ScriptPackageName = 'Repair-Windows-Time-Sync'
$ScriptName = 'Detect'

$ServiceName = 'W32Time'
$AllowLocalCmosClockSource = $false

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

    if ($service.Status -ne 'Running') {
        Write-Output "Not compliant. Service '$ServiceName' is '$($service.Status)'."
        exit 1
    }

    $source = (& w32tm.exe /query /source 2>$null)
    Write-Log -Message "Windows Time source='$source'."

    if (-not $AllowLocalCmosClockSource -and $source -match 'Local CMOS Clock') {
        Write-Output "Not compliant. Time source is '$source'."
        exit 1
    }

    Write-Output "Compliant. Service '$ServiceName' is running and source is '$source'."
    exit 0
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. Windows Time could not be validated."
    exit 1
}
