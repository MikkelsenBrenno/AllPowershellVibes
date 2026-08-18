<#
.SYNOPSIS
    Remediates Ensure Input Personalization Disabled.

.DESCRIPTION
    Intune Remediations action script. It writes the reviewed registry contract and reads every value back before reporting success.

.NOTES
    Name:        Remediate.ps1
    Version:     1.1.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      The final registry type and data are exact
    Exit 1:      The write failed or final validation did not match

.CUSTOMIZATION
    The RegistryValues block is the reviewed package contract. Keep it identical in Detect.ps1 and Remediate.ps1.
#>

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

# =========================
# CONFIGURATION
# =========================

# CUSTOMIZE HERE. The shipped RegistryValues block is the reviewed package contract.
# Keep it identical in Detect.ps1 and Remediate.ps1; rename and re-review the package for a different intent.

$ScriptPackageName = 'Ensure-Input-Personalization-Disabled'
$ScriptName = 'Remediate'

$RegistryValues = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization'; Name = 'AllowInputPersonalization'; Type = 'DWord'; Value = 0; Description = 'Disable input personalization' }
)
$ValidationDelaySeconds = 1

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
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $LogPath -Value "$timestamp [$Level] $Message" -Encoding UTF8
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

function Get-RegistryValueState {
    param([Parameter(Mandatory = $true)][array]$Values)

    foreach ($item in $Values) {
        $keyExists = Test-Path -LiteralPath $item.Path
        $valueExists = $false
        $currentValue = $null
        $currentType = $null

        if ($keyExists) {
            $key = Get-Item -LiteralPath $item.Path -ErrorAction Stop
            $matchingName = @($key.GetValueNames() | Where-Object { $_ -ieq [string]$item.Name } | Select-Object -First 1)
            if ($matchingName.Count -eq 1) {
                $valueExists = $true
                $currentType = $key.GetValueKind([string]$matchingName[0]).ToString()
                $currentValue = $key.GetValue([string]$matchingName[0], $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            }
        }

        $typeMatches = $valueExists -and ([string]$currentType -ceq [string]$item.Type)
        $valueMatches = $valueExists -and [object]::Equals($currentValue, $item.Value)

        [pscustomobject]@{
            Path = $item.Path
            Name = $item.Name
            DesiredType = $item.Type
            DesiredValue = $item.Value
            CurrentType = $currentType
            CurrentValue = $currentValue
            KeyExists = $keyExists
            ValueExists = $valueExists
            TypeMatches = $typeMatches
            ValueMatches = $valueMatches
            Compliant = ($typeMatches -and $valueMatches)
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

        Write-Log -Message "Writing Path='$($item.Path)' Name='$($item.Name)' Type='$($item.Type)' Value='$($item.Value)'."
        New-ItemProperty -LiteralPath $item.Path -Name $item.Name -Value $item.Value -PropertyType $item.Type -Force | Out-Null
    }

    Start-Sleep -Seconds $ValidationDelaySeconds
    $state = @(Get-RegistryValueState -Values $RegistryValues)
    foreach ($item in $state) {
        Write-Log -Message "Validation state Path='$($item.Path)' Name='$($item.Name)' CurrentType='$($item.CurrentType)' DesiredType='$($item.DesiredType)' Current='$($item.CurrentValue)' Desired='$($item.DesiredValue)' Compliant='$($item.Compliant)'."
    }

    $nonCompliant = @($state | Where-Object { -not $_.Compliant })
    if ($nonCompliant.Count -eq 0) {
        $message = 'Remediation succeeded. Every configured registry value has the exact required type and data.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. $($nonCompliant.Count) registry value(s) still have the wrong type or data."
    Write-Log -Message $message -Level 'ERROR'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "$ScriptName failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. The registry contract was not established.'
    exit 1
}
