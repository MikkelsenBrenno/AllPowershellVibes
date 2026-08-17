<#
.SYNOPSIS
    Installs a registry-based configuration marker.

.DESCRIPTION
    Win32 app install script example. The script creates a configurable
    HKLM registry key and value, then validates that the expected value
    exists.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Installation succeeded
    Exit 1:      Installation failed

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

# Keep these names aligned with the folder and script file.
# Logs are written to Logs\<ScriptPackageName>\<ScriptName>.log.
$ScriptPackageName = 'Example-Install-Registry-Setting'
$ScriptName = 'Install'

# Change this to a dedicated registry path for your app or configuration.
# Use 64-bit PowerShell when writing to HKLM:\SOFTWARE on 64-bit Windows.
$RegistryPath = 'HKLM:\SOFTWARE\IntuneScriptLibrary\ExampleInstallRegistrySetting'

# Change these values to the setting your package should install.
$ValueName = 'Configured'
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
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
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
    Write-Log -Message "Install started. RegistryPath='$RegistryPath'; ValueName='$ValueName'."

    if ($ValueType -notin @('String', 'ExpandString', 'DWord', 'QWord', 'MultiString', 'Binary')) {
        throw "ValueType '$ValueType' is not valid."
    }

    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        Write-Log -Message "Creating registry key '$RegistryPath'."
        New-Item -Path $RegistryPath -Force | Out-Null
    }

    Write-Log -Message "Writing registry value '$ValueName'."
    New-ItemProperty -Path $RegistryPath -Name $ValueName -Value $ValueData -PropertyType $ValueType -Force | Out-Null

    $item = Get-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -ErrorAction Stop
    $actualValue = $item.PSObject.Properties[$ValueName].Value

    if ([string]$actualValue -ne [string]$ValueData) {
        throw "Registry validation failed. Expected '$ValueData' but found '$actualValue'."
    }

    $message = "Install succeeded. Registry value '$ValueName' is configured."
    Write-Log -Message $message
    Write-Output $message
    exit 0
}
catch {
    try {
        Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Install failed.'
    exit 1
}

