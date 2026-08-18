<#
.SYNOPSIS
    Detects Microsoft Edge SmartScreen policy values.

.DESCRIPTION
    Intune Remediations detection script. The script checks configured Microsoft Edge SmartScreen registry policy values and exits 1 when any value is missing or different.

.NOTES
    Name:        Detect.ps1
    Version:     1.1.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Edge SmartScreen policy values are compliant
    Exit 1:      Edge SmartScreen policy values are missing or different

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
$ScriptPackageName = 'Ensure-Edge-SmartScreen-Enabled'
$ScriptName = 'Detect'

$RegistryValues = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'SmartScreenEnabled'; Type = 'DWord'; Value = 1 },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'SmartScreenPuaEnabled'; Type = 'DWord'; Value = 1 },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'PreventSmartScreenPromptOverride'; Type = 'DWord'; Value = 1 },
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; Name = 'PreventSmartScreenPromptOverrideForFiles'; Type = 'DWord'; Value = 1 }
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

function Get-ConfiguredRegistryState {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Values
    )

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
            CurrentValue = $currentValue
            CurrentType = $currentType
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
    Write-Log -Message "Detection started. Registry value count='$($RegistryValues.Count)'."

    $state = @(Get-ConfiguredRegistryState -Values $RegistryValues)
    $nonCompliant = @($state | Where-Object { -not $_.Compliant })

    foreach ($item in $state) {
        Write-Log -Message "Registry state Path='$($item.Path)' Name='$($item.Name)' CurrentType='$($item.CurrentType)' DesiredType='$($item.DesiredType)' Current='$($item.CurrentValue)' Desired='$($item.DesiredValue)' Compliant='$($item.Compliant)'."
    }

    if ($nonCompliant.Count -eq 0) {
        $message = "Compliant. All configured registry values match the desired state."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. $($nonCompliant.Count) registry value(s) do not match the desired state."
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

    Write-Output 'Not compliant. Edge SmartScreen policy values could not be validated.'
    exit 1
}
