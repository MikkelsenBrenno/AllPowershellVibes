<#
.SYNOPSIS
    Detects network adapters with Windows power management enabled.

.DESCRIPTION
    Intune Remediations detection script. The script checks physical network
    adapter power management state through root\wmi and reports noncompliance
    when matching adapters allow Windows to disable the device.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Matching adapters already have power saving disabled
    Exit 1:      One or more matching adapters allow power saving

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

$ScriptPackageName = 'Ensure-NIC-Power-Saving-Disabled'
$ScriptName = 'Detect'

$AdapterNamePatterns = @('*Ethernet*', '*Wi-Fi*', '*Wireless*')
$IgnoreDisconnectedAdapters = $false

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Test-NameMatches {
    param([Parameter(Mandatory = $true)][string]$Name)
    foreach ($pattern in $AdapterNamePatterns) {
        if ($Name -like $pattern) {
            return $true
        }
    }
    return $false
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. AdapterNamePatterns='$($AdapterNamePatterns -join ',')'."

    if (-not (Get-Command -Name Get-NetAdapter -ErrorAction SilentlyContinue)) {
        throw 'Get-NetAdapter is not available on this device.'
    }

    $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { Test-NameMatches -Name $_.Name })
    if ($IgnoreDisconnectedAdapters) {
        $adapters = @($adapters | Where-Object { $_.Status -ne 'Disconnected' })
    }

    $powerSettings = @(Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable -ErrorAction Stop)
    $enabledAdapters = @()

    foreach ($adapter in $adapters) {
        $pnpId = [string]$adapter.PnPDeviceID
        $setting = $powerSettings | Where-Object { $_.InstanceName -like "$($pnpId.Replace('\', '\\'))*" } | Select-Object -First 1

        if ($null -ne $setting -and $setting.Enable -eq $true) {
            $enabledAdapters += $adapter.Name
        }
    }

    if ($enabledAdapters.Count -eq 0) {
        $message = 'Compliant. Matching network adapters do not allow Windows power saving.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Power saving enabled on adapters: $($enabledAdapters -join ', ')."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Network adapter power management could not be validated.'
    exit 1
}
