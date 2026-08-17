<#
.SYNOPSIS
    Removes a registry-based configuration marker.

.DESCRIPTION
    Win32 app uninstall script example. The script removes a configurable
    registry value and optionally removes the dedicated registry key.

.NOTES
    Name:        Uninstall.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Uninstallation succeeded
    Exit 1:      Uninstallation failed

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
$ScriptName = 'Uninstall'

# Use the same registry path and value name as Install.ps1.
$RegistryPath = 'HKLM:\SOFTWARE\IntuneScriptLibrary\ExampleInstallRegistrySetting'
$ValueName = 'Configured'

# Keep this $true only when RegistryPath is a dedicated key for this package.
$RemoveRegistryKey = $true

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
    Write-Log -Message "Uninstall started. RegistryPath='$RegistryPath'; ValueName='$ValueName'."

    if (Test-Path -LiteralPath $RegistryPath) {
        $item = Get-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue

        if ($null -ne $item -and $null -ne $item.PSObject.Properties[$ValueName]) {
            Write-Log -Message "Removing registry value '$ValueName'."
            Remove-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -Force
        }
        else {
            Write-Log -Message "Registry value '$ValueName' is already absent."
        }

        if ($RemoveRegistryKey) {
            Write-Log -Message "Removing dedicated registry key '$RegistryPath'."
            Remove-Item -LiteralPath $RegistryPath -Recurse -Force
        }
    }
    else {
        Write-Log -Message "Registry path '$RegistryPath' is already absent."
    }

    if (Test-Path -LiteralPath $RegistryPath) {
        $remaining = Get-ItemProperty -LiteralPath $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue

        if ($null -ne $remaining -and $null -ne $remaining.PSObject.Properties[$ValueName]) {
            throw "Registry value '$ValueName' still exists after uninstall."
        }
    }

    $message = 'Uninstall succeeded.'
    Write-Log -Message $message
    Write-Output $message
    exit 0
}
catch {
    try {
        Write-Log -Message "Uninstall failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Uninstall failed.'
    exit 1
}

