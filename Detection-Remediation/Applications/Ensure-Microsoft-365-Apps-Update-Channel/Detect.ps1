<#
.SYNOPSIS
    Detects whether Microsoft 365 Apps use the expected update channel.

.DESCRIPTION
    Intune Remediations detection script. The script reads Click-to-Run
    configuration registry values and compares the current channel URL with a
    configurable expected channel URL.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Microsoft 365 Apps update channel matches the expected value
    Exit 1:      Microsoft 365 Apps update channel is missing or different

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
$ScriptName = 'Detect'

$ClickToRunConfigurationPath = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
$ExpectedChannelUrl = 'http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6'
$ChannelValueNames = @('CDNBaseUrl', 'UpdateChannel')

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

    if (-not (Test-Path -LiteralPath $ClickToRunConfigurationPath)) {
        Write-Output "Not compliant. Click-to-Run configuration path '$ClickToRunConfigurationPath' was not found."
        exit 1
    }

    $configuration = Get-ItemProperty -LiteralPath $ClickToRunConfigurationPath -ErrorAction Stop
    $differences = @()

    foreach ($valueName in $ChannelValueNames) {
        if ([string]$configuration.$valueName -ne $ExpectedChannelUrl) {
            $differences += "$valueName=$($configuration.$valueName)"
        }
    }

    if ($differences.Count -eq 0) {
        $message = "Compliant. Microsoft 365 Apps update channel matches '$ExpectedChannelUrl'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Channel differences: $($differences -join '; ')."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Microsoft 365 Apps update channel could not be validated.'
    exit 1
}
