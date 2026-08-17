<#
.SYNOPSIS
    Sets a registry value to the expected data.

.DESCRIPTION
    Intune Remediations remediation script. The script creates a configurable
    registry key and writes a configurable value, then validates it.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Registry value was set and validated
    Exit 1:      Registry value could not be set or validated

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
$ScriptName = 'Remediate'

$RegistryPath = 'HKLM:\SOFTWARE\IntuneScriptLibrary\ExamplePolicy'
$ValueName = 'ExampleSetting'
$ValueData = 'Enabled'
$ValueType = 'String'

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
    Write-Log -Message "Remediation started. RegistryPath='$RegistryPath'; ValueName='$ValueName'; ValueData='$ValueData'; ValueType='$ValueType'."

    if ($ValueType -notin @('String', 'ExpandString', 'DWord', 'QWord', 'MultiString', 'Binary')) {
        throw "ValueType '$ValueType' is not valid."
    }

    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        New-Item -Path $RegistryPath -ItemType Directory -Force | Out-Null
    }

    New-ItemProperty -Path $RegistryPath -Name $ValueName -Value $ValueData -PropertyType $ValueType -Force | Out-Null
    $item = Get-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -ErrorAction Stop
    $actualValue = $item.PSObject.Properties[$ValueName].Value

    if ([string]$actualValue -eq [string]$ValueData) {
        $message = "Remediation succeeded. Registry value '$ValueName' is '$actualValue'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    throw "Registry validation failed. Expected '$ValueData' but found '$actualValue'."
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation failed for registry value '$ValueName'."
    exit 1
}
