<#
.SYNOPSIS
    Disables AutoRun and AutoPlay machine policies.

.DESCRIPTION
    Intune Remediations remediation script. The script can write configured
    Explorer policy values that disable AutoRun and AutoPlay. It starts in
    report-only mode so administrators can validate impact before enforcement.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation succeeded
    Exit 1:      Remediation failed or report-only mode is enabled

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
$ScriptPackageName = 'Ensure-AutoRun-AutoPlay-Disabled'
$ScriptName = 'Remediate'

# Machine policy path used by Explorer for AutoRun and AutoPlay behavior.
$ExplorerPolicyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'

# Registry values written by remediation.
# NoDriveTypeAutoRun=255 disables AutoRun for all drive types.
# NoAutorun=1 disables AutoRun commands.
$PolicyValues = @{
    NoDriveTypeAutoRun = 255
    NoAutorun          = 1
}

# Keep report-only mode enabled until the values are approved for your tenant.
$ApplyPolicy = $false
$ExitZeroInReportingOnlyMode = $false

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

function Get-ConfiguredPolicyValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$RegistryItem,

        [Parameter(Mandatory = $true)]
        [string]$ValueName
    )

    if ($RegistryItem.PSObject.Properties.Name -notcontains $ValueName) {
        return $null
    }

    return [int]$RegistryItem.$ValueName
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. ExplorerPolicyPath='$ExplorerPolicyPath'; ApplyPolicy='$ApplyPolicy'."

    if (-not $ApplyPolicy) {
        $message = 'Report-only mode. Set $ApplyPolicy to $true after pilot testing to write AutoRun and AutoPlay policy values.'
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message

        if ($ExitZeroInReportingOnlyMode) {
            exit 0
        }

        exit 1
    }

    if (-not (Test-Path -LiteralPath $ExplorerPolicyPath)) {
        Write-Log -Message "Creating policy path '$ExplorerPolicyPath'."
        New-Item -Path $ExplorerPolicyPath -Force | Out-Null
    }

    foreach ($valueName in $PolicyValues.Keys) {
        $value = [int]$PolicyValues[$valueName]
        Write-Log -Message "Writing policy '$valueName'='$value'."
        New-ItemProperty -Path $ExplorerPolicyPath -Name $valueName -Value $value -PropertyType DWord -Force | Out-Null
    }

    $registryItem = Get-ItemProperty -LiteralPath $ExplorerPolicyPath
    $nonCompliantValues = @()

    foreach ($valueName in $PolicyValues.Keys) {
        $expectedValue = [int]$PolicyValues[$valueName]
        $actualValue = Get-ConfiguredPolicyValue -RegistryItem $registryItem -ValueName $valueName

        Write-Log -Message "Validation '$valueName' Actual='$actualValue' Expected='$expectedValue'."

        if ($null -eq $actualValue -or $actualValue -ne $expectedValue) {
            $nonCompliantValues += "$valueName=$actualValue"
        }
    }

    if ($nonCompliantValues.Count -eq 0) {
        $message = 'Remediation succeeded. AutoRun and AutoPlay policy values match the expected configuration.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. Mismatched policy values: $($nonCompliantValues -join ', ')."
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

    Write-Output 'Remediation failed for AutoRun and AutoPlay policy values.'
    exit 1
}
