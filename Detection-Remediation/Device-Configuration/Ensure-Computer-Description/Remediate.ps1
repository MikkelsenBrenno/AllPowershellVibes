<#
.SYNOPSIS
    Sets the local computer description.

.DESCRIPTION
    Intune Remediations remediation script. The script writes the LanmanServer
    computer description registry value after ApplyDescription is enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Computer description is compliant
    Exit 1:      Computer description remains noncompliant

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

$ScriptPackageName = 'Ensure-Computer-Description'
$ScriptName = 'Remediate'

$LanmanServerParametersPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
$DescriptionValueName = 'srvcomment'
$ExpectedDescription = 'Managed by Contoso IT'
$ApplyDescription = $false
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

    if (-not $ApplyDescription) {
        Write-Output "Computer description would be set to '$ExpectedDescription', but ApplyDescription is disabled."
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    if (-not (Test-Path -LiteralPath $LanmanServerParametersPath -PathType Container)) {
        New-Item -Path $LanmanServerParametersPath -ItemType Directory -Force | Out-Null
    }

    New-ItemProperty -Path $LanmanServerParametersPath -Name $DescriptionValueName -Value $ExpectedDescription -PropertyType String -Force | Out-Null
    $item = Get-ItemProperty -LiteralPath $LanmanServerParametersPath -Name $DescriptionValueName -ErrorAction Stop

    if ([string]$item.$DescriptionValueName -ne $ExpectedDescription) {
        throw 'Computer description validation failed.'
    }

    Write-Output "Computer description set to '$ExpectedDescription'."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed while setting computer description.'
    exit 1
}
