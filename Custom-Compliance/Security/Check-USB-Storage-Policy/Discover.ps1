<#
.SYNOPSIS
    Discovers USB storage policy state for custom compliance.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks the USBSTOR
    service registry startup value and returns one compressed JSON object.

.NOTES
    Name:        Discover.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Custom Compliance
    Output:      Compressed JSON

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

$ScriptPackageName = 'Check-USB-Storage-Policy'
$ScriptName = 'Discover'

$UsbStorageRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR'
$StartValueName = 'Start'
$ExpectedStartValue = 4

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

$result = [ordered]@{
    UsbStoragePolicyCompliant = $false
    RegistryPathExists = $false
    UsbStorageStartValue = -1
    ExpectedStartValue = [int]$ExpectedStartValue
}

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Test-Path -LiteralPath $UsbStorageRegistryPath -PathType Container)) {
        throw "Registry path '$UsbStorageRegistryPath' was not found."
    }

    $item = Get-ItemProperty -LiteralPath $UsbStorageRegistryPath -Name $StartValueName -ErrorAction Stop
    $actualStartValue = [int]$item.$StartValueName

    $result.RegistryPathExists = $true
    $result.UsbStorageStartValue = $actualStartValue
    $result.UsbStoragePolicyCompliant = ($actualStartValue -eq $ExpectedStartValue)

    Write-Log -Message "Discovery completed. Path='$UsbStorageRegistryPath'; StartValue='$actualStartValue'; Expected='$ExpectedStartValue'; Compliant='$($result.UsbStoragePolicyCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.UsbStoragePolicyCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
