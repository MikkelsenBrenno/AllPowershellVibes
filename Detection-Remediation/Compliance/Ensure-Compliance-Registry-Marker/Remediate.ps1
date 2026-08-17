<#
.SYNOPSIS
    Writes a local compliance registry marker.

.DESCRIPTION
    Intune Remediations remediation script. The script writes a configurable
    registry marker and validates the result. It starts in report-only mode so
    administrators can confirm the marker path and value before enforcement.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Registry marker written and validated
    Exit 1:      Remediation failed or report-only mode is enabled

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

$ScriptPackageName = 'Ensure-Compliance-Registry-Marker'
$ScriptName = 'Remediate'

$MarkerRegistryPath = 'HKLM:\SOFTWARE\Microsoft\IntuneScriptLibrary\ComplianceMarker'
$MarkerValueName = 'BaselineVersion'
$MarkerValue = '1.0.0'
$MarkerPropertyType = 'String'

$ApplyMarker = $false
$ExitZeroInReportingOnlyMode = $false

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
    Write-Log -Message "Remediation started. MarkerRegistryPath='$MarkerRegistryPath'; MarkerValueName='$MarkerValueName'; MarkerValue='$MarkerValue'; ApplyMarker='$ApplyMarker'."

    if ($MarkerPropertyType -notin @('String', 'ExpandString', 'DWord', 'QWord', 'MultiString', 'Binary')) {
        throw "MarkerPropertyType '$MarkerPropertyType' is not valid."
    }

    if (-not $ApplyMarker) {
        $message = 'Report-only mode. Set $ApplyMarker to $true after pilot testing to write the registry marker.'
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message

        if ($ExitZeroInReportingOnlyMode) {
            exit 0
        }

        exit 1
    }

    if (-not (Test-Path -LiteralPath $MarkerRegistryPath)) {
        New-Item -Path $MarkerRegistryPath -Force | Out-Null
    }

    New-ItemProperty -Path $MarkerRegistryPath -Name $MarkerValueName -Value $MarkerValue -PropertyType $MarkerPropertyType -Force | Out-Null
    $marker = Get-ItemProperty -LiteralPath $MarkerRegistryPath -ErrorAction Stop
    $actualValue = [string]$marker.$MarkerValueName

    if ($actualValue -eq [string]$MarkerValue) {
        Write-Output "Remediation succeeded. Registry marker '$MarkerValueName' equals '$MarkerValue'."
        exit 0
    }

    throw "Registry marker validation failed. Actual='$actualValue'; Expected='$MarkerValue'."
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed for compliance registry marker.'
    exit 1
}
