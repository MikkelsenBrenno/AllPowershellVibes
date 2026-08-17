<#
.SYNOPSIS
    Detects whether the DNS Client service is running.

.DESCRIPTION
    Intune Remediations detection script. The script checks a Windows service state and exits 1 when remediation should start the service.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      DNS Client service is running
    Exit 1:      DNS Client service is missing or stopped

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
$ScriptPackageName = 'Ensure-DNS-Client-Service-Running'
$ScriptName = 'Detect'

$ServiceName = 'Dnscache'
$DesiredState = 'Running'

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

function Get-ServiceState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $service = Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
    if ($null -eq $service) {
        throw "Service '$Name' was not found."
    }

    return $service
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. ServiceName='$ServiceName'; DesiredState='$DesiredState'."

    $service = Get-ServiceState -Name $ServiceName
    Write-Log -Message "Service state Name='$($service.Name)' State='$($service.State)' StartMode='$($service.StartMode)'."

    if ($service.State -eq $DesiredState) {
        $message = "Compliant. Service '$ServiceName' state is '$($service.State)'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Service '$ServiceName' state is '$($service.State)'. Expected '$DesiredState'."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "$ScriptName failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Not compliant. DNS Client service could not be validated.'
    exit 1
}

