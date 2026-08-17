<#
.SYNOPSIS
    Installs a network printer connection.

.DESCRIPTION
    Win32 app install script example. The script installs a configurable
    network printer connection and validates that it exists.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System or user, depending on printer scope

.INTUNE
    Workload:    Win32 App
    Exit 0:      Printer install succeeded
    Exit 1:      Printer install failed

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

$ScriptPackageName = 'Install-Network-Printer'
$ScriptName = 'Install'

$PrinterConnectionName = '\\printserver\PrinterName'

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

    if ($PrinterConnectionName -eq '\\printserver\PrinterName') {
        throw 'Replace the PrinterConnectionName placeholder before deployment.'
    }

    $existingPrinter = Get-Printer -Name $PrinterConnectionName -ErrorAction SilentlyContinue

    if ($null -eq $existingPrinter) {
        Add-Printer -ConnectionName $PrinterConnectionName -ErrorAction Stop
    }

    $installedPrinter = Get-Printer -Name $PrinterConnectionName -ErrorAction SilentlyContinue
    if ($null -eq $installedPrinter) {
        throw "Printer '$PrinterConnectionName' was not detected after install."
    }

    Write-Output "Install succeeded. Printer '$PrinterConnectionName' is installed."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Install failed for printer '$PrinterConnectionName'."
    exit 1
}
