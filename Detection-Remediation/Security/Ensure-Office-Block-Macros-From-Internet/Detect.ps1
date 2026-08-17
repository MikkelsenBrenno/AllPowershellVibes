<#
.SYNOPSIS
    Detects Office macro-from-internet policy values.

.DESCRIPTION
    Intune Remediations detection script. The script checks configured Office policy registry values and exits 1 when any configured app is missing the desired macro policy.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     User recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Office macro policy values are compliant
    Exit 1:      Office macro policy values are missing or different

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
$ScriptPackageName = 'Ensure-Office-Block-Macros-From-Internet'
$ScriptName = 'Detect'

$OfficePolicyRoot = 'HKCU:\Software\Policies\Microsoft\Office\16.0'
$OfficeAppNames = @('word', 'excel', 'powerpoint', 'access')
$MacroPolicyValueName = 'blockcontentexecutionfrominternet'
$DesiredMacroPolicyValue = 1

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

function Get-OfficeMacroPolicyItems {
    foreach ($appName in $OfficeAppNames) {
        [pscustomobject]@{
            Path = Join-Path -Path $OfficePolicyRoot -ChildPath "$appName\security"
            Name = $MacroPolicyValueName
            Value = $DesiredMacroPolicyValue
            Type = 'DWord'
            App = $appName
        }
    }
}

function Get-OfficeMacroPolicyState {
    $items = @(Get-OfficeMacroPolicyItems)
    foreach ($item in $items) {
        $currentValue = $null
        $compliant = $false

        if (Test-Path -LiteralPath $item.Path) {
            $property = Get-ItemProperty -LiteralPath $item.Path -Name $item.Name -ErrorAction SilentlyContinue
            if ($null -ne $property) {
                $currentValue = $property.($item.Name)
                $compliant = ([string]$currentValue -eq [string]$item.Value)
            }
        }

        [pscustomobject]@{
            App = $item.App
            Path = $item.Path
            Name = $item.Name
            CurrentValue = $currentValue
            DesiredValue = $item.Value
            Compliant = $compliant
        }
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. OfficePolicyRoot='$OfficePolicyRoot'; Apps='$($OfficeAppNames -join ',')'."

    $state = @(Get-OfficeMacroPolicyState)
    $nonCompliant = @($state | Where-Object { -not $_.Compliant })

    foreach ($item in $state) {
        Write-Log -Message "Office macro policy App='$($item.App)' Path='$($item.Path)' Current='$($item.CurrentValue)' Desired='$($item.DesiredValue)' Compliant='$($item.Compliant)'."
    }

    if ($nonCompliant.Count -eq 0) {
        $message = 'Compliant. Office macro-from-internet policy values match the desired state.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. $($nonCompliant.Count) Office app macro policy value(s) are missing or different."
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

    Write-Output 'Not compliant. Office macro policy values could not be validated.'
    exit 1
}

