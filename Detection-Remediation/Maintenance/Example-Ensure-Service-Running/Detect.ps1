<#
.SYNOPSIS
    Detects whether a Windows service is running.

.DESCRIPTION
    Intune Remediations detection script. The script checks a configurable
    Windows service and exits 0 when the service is in the required state.
    It exits 1 when remediation should run.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Service is compliant
    Exit 1:      Service is missing or not compliant

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
$ScriptName = 'Detect'

# Change this to the service name you want to monitor.
# Use the service name, not the display name. Example: 'Spooler'.
$ServiceName = 'Spooler'

# Change this if your scenario requires a different service status.
$RequiredStatus = 'Running'

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
    Write-Log -Message "Detection started. ServiceName='$ServiceName'; RequiredStatus='$RequiredStatus'."

    $service = Get-Service -Name $ServiceName -ErrorAction Stop
    $currentStatus = $service.Status.ToString()

    if ($currentStatus -eq $RequiredStatus) {
        $message = "Compliant. Service '$ServiceName' is '$currentStatus'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Service '$ServiceName' is '$currentStatus'. Expected '$RequiredStatus'."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "Detection failed or service was not found. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output "Not compliant. Service '$ServiceName' could not be validated."
    exit 1
}

