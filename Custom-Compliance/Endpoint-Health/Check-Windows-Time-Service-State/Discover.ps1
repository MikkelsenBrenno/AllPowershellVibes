<#
.SYNOPSIS
    Discovers Windows Time service state for custom compliance.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks Windows Time
    service state and optionally flags Local CMOS Clock as noncompliant, then
    returns one compressed JSON object.

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

$ScriptPackageName = 'Check-Windows-Time-Service-State'
$ScriptName = 'Discover'

$ServiceName = 'W32Time'
$RequireRunning = $false
$AllowedStartModes = @('Auto', 'Manual')
$AllowLocalCmosClockSource = $false

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
    WindowsTimeServiceCompliant = $false
    ServiceExists = $false
    ServiceName = $ServiceName
    ServiceStartMode = ''
    ServiceState = ''
    TimeSource = ''
    LocalCmosClockDetected = $false
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
    if ($null -eq $service) {
        throw "Service '$ServiceName' was not found."
    }

    $source = (& w32tm.exe /query /source 2>$null)
    if ($null -eq $source) {
        $source = ''
    }

    $result.ServiceExists = $true
    $result.ServiceStartMode = [string]$service.StartMode
    $result.ServiceState = [string]$service.State
    $result.TimeSource = [string]$source
    $result.LocalCmosClockDetected = ($result.TimeSource -match 'Local CMOS Clock')
    $result.WindowsTimeServiceCompliant = (
        $AllowedStartModes -contains $result.ServiceStartMode -and
        (-not $RequireRunning -or $result.ServiceState -eq 'Running') -and
        ($AllowLocalCmosClockSource -or -not $result.LocalCmosClockDetected)
    )

    Write-Log -Message "Discovery completed. Service='$ServiceName'; StartMode='$($result.ServiceStartMode)'; State='$($result.ServiceState)'; Source='$($result.TimeSource)'; Compliant='$($result.WindowsTimeServiceCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.WindowsTimeServiceCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
