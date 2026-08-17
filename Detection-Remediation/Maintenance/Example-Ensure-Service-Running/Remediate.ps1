<#
.SYNOPSIS
    Starts a Windows service when it is not running.

.DESCRIPTION
    Intune Remediations remediation script. The script optionally sets a
    service startup type, starts the service, validates the final state,
    and exits 0 only when the service is running.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation succeeded
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

# Keep these names aligned with the folder and script file.
# Logs are written to Logs\<ScriptPackageName>\<ScriptName>.log.
$ScriptPackageName = 'Example-Ensure-Service-Running'
$ScriptName = 'Remediate'

# Change this to the service name you want to remediate.
# Use the service name, not the display name. Example: 'Spooler'.
$ServiceName = 'Spooler'

# Choose one of: Automatic, Manual, Disabled, DoNotChange.
# Use DoNotChange if you only want to start the service.
$DesiredStartupType = 'Automatic'

# Set to $false if you only want to change startup type.
$StartServiceIfStopped = $true

# Increase this if the service needs more time to transition to Running.
$ValidationDelaySeconds = 3

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

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. ServiceName='$ServiceName'; DesiredStartupType='$DesiredStartupType'."

    $service = Get-Service -Name $ServiceName -ErrorAction Stop
    Write-Log -Message "Current service status is '$($service.Status)'."

    if ($DesiredStartupType -ne 'DoNotChange') {
        if ($DesiredStartupType -notin @('Automatic', 'Manual', 'Disabled')) {
            throw "DesiredStartupType '$DesiredStartupType' is not valid."
        }

        Write-Log -Message "Setting startup type to '$DesiredStartupType'."
        Set-Service -Name $ServiceName -StartupType $DesiredStartupType
    }

    if ($StartServiceIfStopped) {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop

        if ($service.Status.ToString() -ne 'Running') {
            Write-Log -Message "Starting service '$ServiceName'."
            Start-Service -Name $ServiceName
        }
    }

    Start-Sleep -Seconds $ValidationDelaySeconds

    $service = Get-Service -Name $ServiceName -ErrorAction Stop
    $currentStatus = $service.Status.ToString()

    if ($currentStatus -eq 'Running') {
        $message = "Remediation succeeded. Service '$ServiceName' is running."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. Service '$ServiceName' is '$currentStatus'."
    Write-Log -Message $message -Level 'ERROR'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output "Remediation failed for service '$ServiceName'."
    exit 1
}

