<#
.SYNOPSIS
    Detects whether AutoRun and AutoPlay machine policies are disabled.

.DESCRIPTION
    Intune Remediations detection script. The script checks configured
    Explorer policy values and exits 0 when AutoRun and AutoPlay are disabled.
    It exits 1 when remediation should run.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Configured AutoRun and AutoPlay policy values match
    Exit 1:      One or more configured values are missing or different

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
$ScriptName = 'Detect'

# Machine policy path used by Explorer for AutoRun and AutoPlay behavior.
$ExplorerPolicyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'

# Registry values expected by detection.
# NoDriveTypeAutoRun=255 disables AutoRun for all drive types.
# NoAutorun=1 disables AutoRun commands.
$ExpectedPolicyValues = @{
    NoDriveTypeAutoRun = 255
    NoAutorun          = 1
}

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
    Write-Log -Message "Detection started. ExplorerPolicyPath='$ExplorerPolicyPath'."

    if (-not (Test-Path -LiteralPath $ExplorerPolicyPath)) {
        $message = "Not compliant. Policy path '$ExplorerPolicyPath' does not exist."
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message
        exit 1
    }

    $registryItem = Get-ItemProperty -LiteralPath $ExplorerPolicyPath
    $nonCompliantValues = @()

    foreach ($valueName in $ExpectedPolicyValues.Keys) {
        $expectedValue = [int]$ExpectedPolicyValues[$valueName]
        $actualValue = Get-ConfiguredPolicyValue -RegistryItem $registryItem -ValueName $valueName

        Write-Log -Message "Policy '$valueName' Actual='$actualValue' Expected='$expectedValue'."

        if ($null -eq $actualValue -or $actualValue -ne $expectedValue) {
            $nonCompliantValues += "$valueName=$actualValue"
        }
    }

    if ($nonCompliantValues.Count -eq 0) {
        $message = 'Compliant. AutoRun and AutoPlay policy values match the expected configuration.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Mismatched policy values: $($nonCompliantValues -join ', ')."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Not compliant. AutoRun and AutoPlay policy values could not be validated.'
    exit 1
}
