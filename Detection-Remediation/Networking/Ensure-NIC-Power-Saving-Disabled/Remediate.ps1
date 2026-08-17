<#
.SYNOPSIS
    Disables Windows power saving for matching network adapters.

.DESCRIPTION
    Intune Remediations remediation script. The script can update
    MSPower_DeviceEnable records for matching physical network adapters. It is
    report-only by default so technicians can pilot the adapter matching first.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation completed or report-only mode completed
    Exit 1:      Remediation failed

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
$ScriptName = 'Remediate'

$AdapterNamePatterns = @('*Ethernet*', '*Wi-Fi*', '*Wireless*')
$IgnoreDisconnectedAdapters = $false
$ApplyPowerManagementChange = $false

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
    Write-Log -Message "Remediation started. ApplyPowerManagementChange='$ApplyPowerManagementChange'."

    if (-not (Get-Command -Name Get-NetAdapter -ErrorAction SilentlyContinue)) {
        throw 'Get-NetAdapter is not available on this device.'
    }

    $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { Test-NameMatches -Name $_.Name })
    if ($IgnoreDisconnectedAdapters) {
        $adapters = @($adapters | Where-Object { $_.Status -ne 'Disconnected' })
    }

    $powerSettings = @(Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable -ErrorAction Stop)
    $updatedAdapters = @()
    $candidateAdapters = @()

    foreach ($adapter in $adapters) {
        $pnpId = [string]$adapter.PnPDeviceID
        $setting = $powerSettings | Where-Object { $_.InstanceName -like "$($pnpId.Replace('\', '\\'))*" } | Select-Object -First 1

        if ($null -ne $setting -and $setting.Enable -eq $true) {
            $candidateAdapters += $adapter.Name

            if ($ApplyPowerManagementChange) {
                $setting.Enable = $false
                Set-CimInstance -InputObject $setting -ErrorAction Stop | Out-Null
                $updatedAdapters += $adapter.Name
            }
        }
    }

    if (-not $ApplyPowerManagementChange) {
        $message = "Report-only mode. Would disable power saving on: $($candidateAdapters -join ', ')."
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message
        exit 0
    }

    $message = "Remediation completed. Updated adapters: $($updatedAdapters -join ', ')."
    Write-Log -Message $message
    Write-Output $message
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Network adapter power management was not changed.'
    exit 1
}
