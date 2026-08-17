<#
.SYNOPSIS
    Resets selected Windows Update components.

.DESCRIPTION
    Intune Remediations remediation script. The script can stop update-related
    services, rename selected cache folders, and restart services. It starts in
    report-only mode so administrators can validate impact before enforcement.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Reset completed
    Exit 1:      Reset failed or report-only mode is enabled

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

$ScriptPackageName = 'Reset-Windows-Update-Components-Safely'
$ScriptName = 'Remediate'

$ServicesToRestart = @('wuauserv', 'BITS', 'cryptsvc')
$CacheFoldersToRename = @(
    (Join-Path -Path $env:SystemRoot -ChildPath 'SoftwareDistribution\Download'),
    (Join-Path -Path $env:SystemRoot -ChildPath 'System32\catroot2')
)
$ApplyReset = $false
$ExitZeroInReportingOnlyMode = $false
$ServiceStopTimeoutSeconds = 30

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

    if (-not $ApplyReset) {
        $message = 'Report-only mode. Set $ApplyReset to $true after pilot testing to reset selected Windows Update components.'
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message

        if ($ExitZeroInReportingOnlyMode) {
            exit 0
        }

        exit 1
    }

    foreach ($serviceName in $ServicesToRestart) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -ne $service -and $service.Status -ne 'Stopped') {
            Write-Log -Message "Stopping service '$serviceName'."
            Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
            $service.WaitForStatus('Stopped', [TimeSpan]::FromSeconds($ServiceStopTimeoutSeconds))
        }
    }

    $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
    foreach ($folder in $CacheFoldersToRename) {
        if (Test-Path -LiteralPath $folder -PathType Container) {
            $newName = "$folder.IntuneReset.$timestamp"
            Write-Log -Message "Renaming '$folder' to '$newName'."
            Rename-Item -LiteralPath $folder -NewName (Split-Path -Path $newName -Leaf) -ErrorAction Stop
        }
    }

    foreach ($serviceName in $ServicesToRestart) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($null -ne $service) {
            Write-Log -Message "Starting service '$serviceName'."
            Start-Service -Name $serviceName -ErrorAction SilentlyContinue
        }
    }

    Write-Output 'Remediation succeeded. Selected Windows Update components were reset.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed for Windows Update component reset.'
    exit 1
}
