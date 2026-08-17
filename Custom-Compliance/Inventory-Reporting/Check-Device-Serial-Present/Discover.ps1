<#
.SYNOPSIS
    Discovers whether a device serial number is present.

.DESCRIPTION
    Intune custom compliance discovery script. The script reads BIOS serial
    number data and returns one compressed JSON object.

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

$ScriptPackageName = 'Check-Device-Serial-Present'
$ScriptName = 'Discover'

$InvalidSerialValues = @('To Be Filled By O.E.M.', 'Default string', 'System Serial Number', 'None', 'Unknown')

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
    DeviceSerialPresent = $false
    SerialNumber = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata
    $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop
    $serial = ([string]$bios.SerialNumber).Trim()
    $result.SerialNumber = $serial
    $result.DeviceSerialPresent = (-not [string]::IsNullOrWhiteSpace($serial) -and $InvalidSerialValues -notcontains $serial)
    Write-Log -Message "Discovery completed. SerialPresent='$($result.DeviceSerialPresent)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.DeviceSerialPresent = $false
    $result.SerialNumber = 'Error'
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
