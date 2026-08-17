<#
.SYNOPSIS
    Detects whether a registry value matches the expected data.

.DESCRIPTION
    Intune Remediations detection script. The script checks a configurable
    registry path, value name, and expected value.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Registry value is compliant
    Exit 1:      Registry value is missing or different

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

$ScriptPackageName = 'Ensure-Registry-Value'
$ScriptName = 'Detect'

$RegistryPath = 'HKLM:\SOFTWARE\IntuneScriptLibrary\ExamplePolicy'
$ValueName = 'ExampleSetting'
$ExpectedValueData = 'Enabled'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -Path $LogPath -Value "$timestamp [$Level] $Message" -Encoding UTF8
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
    Write-Log -Message "Detection started. RegistryPath='$RegistryPath'; ValueName='$ValueName'; ExpectedValueData='$ExpectedValueData'."

    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        Write-Log -Message "Registry path does not exist." -Level 'WARN'
        Write-Output "Not compliant. Registry path '$RegistryPath' does not exist."
        exit 1
    }

    $item = Get-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -ErrorAction Stop
    $actualValue = $item.PSObject.Properties[$ValueName].Value

    if ([string]$actualValue -eq [string]$ExpectedValueData) {
        $message = "Compliant. Registry value '$ValueName' is '$actualValue'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    Write-Log -Message "Registry value mismatch. Actual='$actualValue'." -Level 'WARN'
    Write-Output "Not compliant. Registry value '$ValueName' does not match expected data."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. Registry value '$ValueName' could not be validated."
    exit 1
}
