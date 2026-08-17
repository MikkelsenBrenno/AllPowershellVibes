<#
.SYNOPSIS
    Sets the Microsoft 365 Apps update channel registry values.

.DESCRIPTION
    Intune Remediations remediation script. The script can update Click-to-Run
    channel values and optionally trigger OfficeC2RClient to update. It is
    report-only by default.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation completed or report-only mode completed
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

$ScriptPackageName = 'Ensure-Microsoft-365-Apps-Update-Channel'
$ScriptName = 'Remediate'

$ClickToRunConfigurationPath = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
$TargetChannelUrl = 'http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6'
$ChannelValueNames = @('CDNBaseUrl', 'UpdateChannel')
$OfficeC2RClientPath = Join-Path -Path $env:ProgramFiles -ChildPath 'Common Files\Microsoft Shared\ClickToRun\OfficeC2RClient.exe'
$TriggerOfficeUpdateAfterChange = $false
$ApplyChannelChange = $false

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

    if (-not $ApplyChannelChange) {
        Write-Output "Report-only mode. Would set Microsoft 365 Apps channel values to '$TargetChannelUrl'."
        exit 0
    }

    if (-not (Test-Path -LiteralPath $ClickToRunConfigurationPath)) {
        New-Item -Path $ClickToRunConfigurationPath -Force | Out-Null
    }

    foreach ($valueName in $ChannelValueNames) {
        New-ItemProperty -LiteralPath $ClickToRunConfigurationPath -Name $valueName -PropertyType String -Value $TargetChannelUrl -Force | Out-Null
        Write-Log -Message "Set '$valueName' to '$TargetChannelUrl'."
    }

    if ($TriggerOfficeUpdateAfterChange -and (Test-Path -LiteralPath $OfficeC2RClientPath -PathType Leaf)) {
        Start-Process -FilePath $OfficeC2RClientPath -ArgumentList @('/update', 'user') -WindowStyle Hidden
        Write-Log -Message 'Triggered OfficeC2RClient update user.'
    }

    Write-Output 'Remediation completed. Microsoft 365 Apps update channel was configured.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Microsoft 365 Apps update channel was not configured.'
    exit 1
}
