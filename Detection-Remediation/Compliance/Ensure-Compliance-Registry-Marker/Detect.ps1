<#
.SYNOPSIS
    Detects a local compliance registry marker.

.DESCRIPTION
    Intune Remediations detection script. The script checks a configurable
    registry value and exits 0 when the value matches. It exits 1 when the
    marker is missing or different.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Registry marker matches
    Exit 1:      Registry marker missing or different

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
$ScriptName = 'Detect'

$MarkerRegistryPath = 'HKLM:\SOFTWARE\Microsoft\IntuneScriptLibrary\ComplianceMarker'
$MarkerValueName = 'BaselineVersion'
$ExpectedMarkerValue = '1.0.0'

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
    Write-Log -Message "Detection started. MarkerRegistryPath='$MarkerRegistryPath'; MarkerValueName='$MarkerValueName'; ExpectedMarkerValue='$ExpectedMarkerValue'."

    if (-not (Test-Path -LiteralPath $MarkerRegistryPath)) {
        Write-Output "Not compliant. Registry marker path '$MarkerRegistryPath' is missing."
        exit 1
    }

    $marker = Get-ItemProperty -LiteralPath $MarkerRegistryPath -ErrorAction Stop
    $actualValue = [string]$marker.$MarkerValueName
    Write-Log -Message "ActualMarkerValue='$actualValue'."

    if ($actualValue -eq $ExpectedMarkerValue) {
        Write-Output "Compliant. Registry marker '$MarkerValueName' equals '$ExpectedMarkerValue'."
        exit 0
    }

    Write-Output "Not compliant. Registry marker '$MarkerValueName' equals '$actualValue'."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Registry marker could not be validated.'
    exit 1
}
