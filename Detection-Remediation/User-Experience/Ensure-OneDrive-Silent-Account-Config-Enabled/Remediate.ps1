<#
.SYNOPSIS
    Remediates Ensure OneDrive Silent Account Config Enabled.

.DESCRIPTION
    Intune Remediations remediation script. The script writes configured registry values and validates the final state.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Ensure OneDrive Silent Account Config Enabled remediation succeeded
    Exit 1:      Ensure OneDrive Silent Account Config Enabled remediation failed

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
$ScriptPackageName = 'Ensure-OneDrive-Silent-Account-Config-Enabled'
$ScriptName = 'Remediate'

$RegistryValues = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive'; Name = 'SilentAccountConfig'; Type = 'DWord'; Value = 1; Description = 'Enable OneDrive silent account configuration' }
)
$ValidationDelaySeconds = 2

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

function Get-RegistryValueState {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Values
    )

    foreach ($item in $Values) {
        $exists = Test-Path -LiteralPath $item.Path
        $currentValue = $null
        $compliant = $false

        if ($exists) {
            $property = Get-ItemProperty -LiteralPath $item.Path -Name $item.Name -ErrorAction SilentlyContinue
            if ($null -ne $property) {
                $currentValue = $property.($item.Name)
                $compliant = ([string]$currentValue -eq [string]$item.Value)
            }
        }

        [pscustomobject]@{
            Path = $item.Path
            Name = $item.Name
            Type = $item.Type
            DesiredValue = $item.Value
            CurrentValue = $currentValue
            Exists = $exists
            Compliant = $compliant
            Description = $item.Description
        }
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. Registry value count='$($RegistryValues.Count)'."

    foreach ($item in $RegistryValues) {
        if (-not (Test-Path -LiteralPath $item.Path)) {
            New-Item -Path $item.Path -Force | Out-Null
        }

        Write-Log -Message "Setting registry value Path='$($item.Path)' Name='$($item.Name)' Type='$($item.Type)' Value='$($item.Value)'."
        New-ItemProperty -LiteralPath $item.Path -Name $item.Name -Value $item.Value -PropertyType $item.Type -Force | Out-Null
    }

    Start-Sleep -Seconds $ValidationDelaySeconds
    $state = @(Get-RegistryValueState -Values $RegistryValues)
    $nonCompliant = @($state | Where-Object { -not $_.Compliant })

    if ($nonCompliant.Count -eq 0) {
        $message = 'Remediation succeeded. All configured registry values match the desired state.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. $($nonCompliant.Count) registry value(s) are still missing or different."
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

    Write-Output 'Remediation failed for Ensure OneDrive Silent Account Config Enabled.'
    exit 1
}

