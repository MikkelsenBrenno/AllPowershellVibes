<#
.SYNOPSIS
    Detects network adapters where NetBIOS over TCP/IP is not disabled.

.DESCRIPTION
    Intune Remediations detection script. The script checks IP-enabled network
    adapter configurations and reports noncompliance when matching adapters do
    not have TcpipNetbiosOptions set to disabled.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Matching adapters have NetBIOS over TCP/IP disabled
    Exit 1:      One or more matching adapters are not disabled

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
$ScriptName = 'Detect'

$AdapterDescriptionPatterns = @('*')
$ExpectedTcpipNetbiosOptions = 2

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

    $adapters = @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled = True' -ErrorAction Stop | Where-Object { Test-AdapterDescriptionMatch -Description ([string]$_.Description) })
    $notCompliant = @()

    foreach ($adapter in $adapters) {
        if ([int]$adapter.TcpipNetbiosOptions -ne [int]$ExpectedTcpipNetbiosOptions) {
            $notCompliant += "$($adapter.Description)=$($adapter.TcpipNetbiosOptions)"
        }
    }

    if ($notCompliant.Count -eq 0) {
        $message = 'Compliant. NetBIOS over TCP/IP is disabled on matching adapters.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Adapter values: $($notCompliant -join ', ')."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. NetBIOS over TCP/IP could not be validated.'
    exit 1
}
