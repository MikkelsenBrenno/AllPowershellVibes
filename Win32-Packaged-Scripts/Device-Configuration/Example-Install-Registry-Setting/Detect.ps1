<#
.SYNOPSIS
    Detects a registry-based configuration marker.

.DESCRIPTION
    Win32 app custom detection script example. Intune considers the app
    detected only when this script exits 0 and writes a string to STDOUT.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Detection
    Exit 0:      Configuration detected, with STDOUT
    Exit 1:      Configuration not detected

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
$ScriptName = 'Detect'

# Use the same values as Install.ps1.
$RegistryPath = 'HKLM:\SOFTWARE\IntuneScriptLibrary\ExampleInstallRegistrySetting'
$ValueName = 'Configured'
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
    Write-Log -Message "Detection started. RegistryPath='$RegistryPath'; ValueName='$ValueName'."

    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        Write-Log -Message "Not detected. Registry path does not exist." -Level 'WARN'
        exit 1
    }

    $item = Get-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -ErrorAction Stop
    $actualValue = $item.PSObject.Properties[$ValueName].Value

    if ([string]$actualValue -eq [string]$ExpectedValueData) {
        $message = "Detected. Registry value '$ValueName' is '$actualValue'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    Write-Log -Message "Not detected. Expected '$ExpectedValueData' but found '$actualValue'." -Level 'WARN'
    exit 1
}
catch {
    try {
        Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    exit 1
}

