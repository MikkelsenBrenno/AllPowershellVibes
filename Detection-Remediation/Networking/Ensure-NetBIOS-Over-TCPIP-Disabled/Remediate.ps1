<#
.SYNOPSIS
    Disables NetBIOS over TCP/IP on matching adapters.

.DESCRIPTION
    Intune Remediations remediation script. The script can call
    SetTcpipNetbios for matching IP-enabled adapters. It is report-only by
    default so network teams can validate adapter matching first.

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

$ScriptPackageName = 'Ensure-NetBIOS-Over-TCPIP-Disabled'
$ScriptName = 'Remediate'

$AdapterDescriptionPatterns = @('*')
$TargetTcpipNetbiosOptions = 2
$ApplyNetBiosChange = $false

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Test-AdapterDescriptionMatch {
    param([Parameter(Mandatory = $true)][string]$Description)

    foreach ($pattern in $AdapterDescriptionPatterns) {
        if ($Description -like $pattern) {
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
    Write-Log -Message "Remediation started. ApplyNetBiosChange='$ApplyNetBiosChange'; TargetTcpipNetbiosOptions='$TargetTcpipNetbiosOptions'."

    $adapters = @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = True' -ErrorAction Stop | Where-Object { Test-AdapterDescriptionMatch -Description ([string]$_.Description) })
    $targets = @($adapters | Where-Object { [int]$_.TcpipNetbiosOptions -ne [int]$TargetTcpipNetbiosOptions })

    if ($targets.Count -eq 0) {
        Write-Output 'No change needed. NetBIOS over TCP/IP is already disabled on matching adapters.'
        exit 0
    }

    if (-not $ApplyNetBiosChange) {
        Write-Output "Report-only mode. Would update adapters: $(@($targets | Select-Object -ExpandProperty Description) -join ', ')."
        exit 0
    }

    foreach ($adapter in $targets) {
        Write-Log -Message "Updating adapter '$($adapter.Description)' from '$($adapter.TcpipNetbiosOptions)' to '$TargetTcpipNetbiosOptions'."
        $result = Invoke-CimMethod -InputObject $adapter -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]$TargetTcpipNetbiosOptions } -ErrorAction Stop
        Write-Log -Message "SetTcpipNetbios result for '$($adapter.Description)': ReturnValue='$($result.ReturnValue)'."
    }

    Write-Output 'Remediation completed. NetBIOS over TCP/IP settings were updated.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. NetBIOS over TCP/IP settings were not changed.'
    exit 1
}
