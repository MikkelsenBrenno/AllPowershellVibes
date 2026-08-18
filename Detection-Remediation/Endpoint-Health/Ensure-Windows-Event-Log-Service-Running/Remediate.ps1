<#
.SYNOPSIS
    Starts Windows Event Log Service.

.DESCRIPTION
    Intune Remediations remediation script. The script starts the configured Windows service and validates the final state.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Windows Event Log Service remediation succeeded
    Exit 1:      Windows Event Log Service remediation failed

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
$ScriptPackageName = 'Ensure-Windows-Event-Log-Service-Running'
$ScriptName = 'Remediate'

$ServiceName = 'EventLog'
$ExpectedState = 'Running'
$StartService = $true
$ValidationDelaySeconds = 5

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

function Get-ManagedService {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return Get-CimInstance -ClassName Win32_Service -Filter "Name='$Name'" -ErrorAction SilentlyContinue
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. ServiceName='$ServiceName'; ExpectedState='$ExpectedState'; StartService='$StartService'."

    $service = Get-ManagedService -Name $ServiceName
    if ($null -eq $service) {
        throw "Service '$ServiceName' was not found."
    }

    if ($service.State -ne $ExpectedState) {
        if (-not $StartService) {
            $message = "Report-only mode. Set `$StartService to `$true to start service '$ServiceName'."
            Write-Log -Message $message -Level 'WARN'
            Write-Output $message
            exit 1
        }

        Write-Log -Message "Starting service '$ServiceName'."
        Start-Service -Name $ServiceName -ErrorAction Stop
    }

    Start-Sleep -Seconds $ValidationDelaySeconds
    $updatedService = Get-ManagedService -Name $ServiceName

    if ($null -ne $updatedService -and $updatedService.State -eq $ExpectedState) {
        $message = "Remediation succeeded. Service '$ServiceName' state is '$ExpectedState'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. Service '$ServiceName' state is '$($updatedService.State)'. Expected '$ExpectedState'."
    Write-Log -Message $message -Level 'ERROR'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "$ScriptName failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Remediation failed for Windows Event Log Service.'
    exit 1
}

