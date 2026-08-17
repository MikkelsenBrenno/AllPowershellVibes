<#
.SYNOPSIS
    Detects BitLocker Baseline Marker state.

.DESCRIPTION
    Detects and remediates BitLocker Baseline Marker state for Intune-managed Windows devices.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      BitLocker Baseline Marker is compliant
    Exit 1:      BitLocker Baseline Marker is noncompliant

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

$ScriptPackageName = 'Ensure-BitLocker-Baseline-Marker'
$ScriptName = 'Detect'

$ManagedSettingName = 'BitLocker Baseline Marker'
$RegistryPath = 'HKLM:\SOFTWARE\Policies\Contoso\Compliance'
$ValueName = 'BitLockerBaselineMarker'
$ExpectedValue = 'Enabled'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"
$script:LogAvailable = $false

function Initialize-Log {
    try {
        if (-not (Test-Path -LiteralPath $LogRoot -PathType Container)) {
            New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
        }

        $script:LogAvailable = $true
    }
    catch {
        $script:LogAvailable = $false
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    if (-not $script:LogAvailable) {
        return
    }

    try {
        Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8
    }
    catch {
        $script:LogAvailable = $false
    }
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. ManagedSettingName='$ManagedSettingName'; RegistryPath='$RegistryPath'; ValueName='$ValueName'; ExpectedValue='$ExpectedValue'."

    if (-not (Test-Path -LiteralPath $RegistryPath -PathType Container)) {
        Write-Output "Not compliant. Registry path '$RegistryPath' is missing for '$ManagedSettingName'."
        exit 1
    }

    $property = Get-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue
    if ($null -eq $property -or $null -eq $property.$ValueName) {
        Write-Output "Not compliant. Registry value '$ValueName' is missing for '$ManagedSettingName'."
        exit 1
    }

    $actualValue = [string]$property.$ValueName
    if ($actualValue -eq $ExpectedValue) {
        Write-Output "Compliant. '$ManagedSettingName' is '$ExpectedValue'."
        exit 0
    }

    Write-Output "Not compliant. '$ManagedSettingName' is '$actualValue'; expected '$ExpectedValue'."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. '$ManagedSettingName' could not be validated."
    exit 1
}
