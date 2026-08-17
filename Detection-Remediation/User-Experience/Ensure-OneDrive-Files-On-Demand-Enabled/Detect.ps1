<#
.SYNOPSIS
    Detects Ensure OneDrive Files On Demand Enabled.

.DESCRIPTION
    Intune Remediations detection script. The script checks configured registry values and exits 1 when remediation should write the desired state.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Ensure OneDrive Files On Demand Enabled is compliant
    Exit 1:      Ensure OneDrive Files On Demand Enabled is missing or different

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
$ScriptPackageName = 'Ensure-OneDrive-Files-On-Demand-Enabled'
$ScriptName = 'Detect'

$RegistryValues = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\OneDrive'; Name = 'FilesOnDemandEnabled'; Type = 'DWord'; Value = 1; Description = 'Enable OneDrive Files On-Demand' }
)

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
    Write-Log -Message "Detection started. Registry value count='$($RegistryValues.Count)'."

    $state = @(Get-RegistryValueState -Values $RegistryValues)
    foreach ($item in $state) {
        Write-Log -Message "Registry state Path='$($item.Path)' Name='$($item.Name)' Current='$($item.CurrentValue)' Desired='$($item.DesiredValue)' Compliant='$($item.Compliant)'."
    }

    $nonCompliant = @($state | Where-Object { -not $_.Compliant })
    if ($nonCompliant.Count -eq 0) {
        $message = 'Compliant. All configured registry values match the desired state.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. $($nonCompliant.Count) configured registry value(s) are missing or different."
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

    Write-Output 'Not compliant. Ensure OneDrive Files On Demand Enabled could not be validated.'
    exit 1
}

