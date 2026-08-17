<#
.SYNOPSIS
    Discovers Remote Registry service state for custom compliance.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks whether the
    Remote Registry service exists, has the expected startup mode, and is
    stopped when required, then returns one compressed JSON object.

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

$ScriptPackageName = 'Check-Remote-Registry-Service-State'
$ScriptName = 'Discover'

$ServiceName = 'RemoteRegistry'
$ExpectedStartMode = 'Disabled'
$RequireStopped = $true

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
    RemoteRegistryServiceCompliant = $false
    ServiceExists = $false
    ServiceName = $ServiceName
    ServiceStartMode = ''
    ServiceState = ''
    ExpectedStartMode = $ExpectedStartMode
    RequireStopped = [bool]$RequireStopped
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
    if ($null -eq $service) {
        throw "Service '$ServiceName' was not found."
    }

    $result.ServiceExists = $true
    $result.ServiceStartMode = [string]$service.StartMode
    $result.ServiceState = [string]$service.State
    $result.RemoteRegistryServiceCompliant = (
        $result.ServiceStartMode -eq $ExpectedStartMode -and
        (-not $RequireStopped -or $result.ServiceState -eq 'Stopped')
    )

    Write-Log -Message "Discovery completed. Service='$ServiceName'; StartMode='$($result.ServiceStartMode)'; State='$($result.ServiceState)'; Compliant='$($result.RemoteRegistryServiceCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.RemoteRegistryServiceCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
