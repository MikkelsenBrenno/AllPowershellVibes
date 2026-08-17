<#
.SYNOPSIS
    Exports Defender ASR rule preference state.

.DESCRIPTION
    Intune platform script for Microsoft 365 Business Premium environments. The script exports local Defender ASR preference state to JSON for technician review.

.NOTES
    Name:        Export-ASR-Rule-Preference-State.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune Platform Script
    Exit 0:      ASR rule state exported
    Exit 1:      ASR rule state export failed

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
$ScriptPackageName = 'Export-ASR-Rule-Preference-State'
$ScriptName = 'Export-ASR-Rule-Preference-State'

$OutputRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$OutputFileName = 'ASRRulePreferenceState.json'
$JsonDepth = 8

$KnownASRRuleNames = @{
    'BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550' = 'Block executable content from email and webmail'
    'D4F940AB-401B-4EFC-AADC-AD5F3C50688A' = 'Block Office child processes'
    '3B576869-A4EC-4529-8536-B80A7769E899' = 'Block Office creating executable content'
    '75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84' = 'Block Office injecting code'
    'D3E037E1-3EB8-44C8-A917-57927947596D' = 'Block JavaScript or VBScript launching downloaded executables'
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

    if (-not (Test-Path -LiteralPath $OutputRoot)) {
        New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null
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

function Get-RegistrySnapshot {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Items
    )

    foreach ($item in $Items) {
        $exists = Test-Path -LiteralPath $item.Path
        $value = $null

        if ($exists) {
            $property = Get-ItemProperty -LiteralPath $item.Path -Name $item.Name -ErrorAction SilentlyContinue
            if ($null -ne $property) {
                $value = $property.($item.Name)
            }
        }

        [pscustomobject]@{
            Path = $item.Path
            Name = $item.Name
            Exists = $exists
            Value = $value
            Description = $item.Description
        }
    }
}

function ConvertTo-StringArray {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return @()
    }

    return @($Value | ForEach-Object { [string]$_ })
}

function Convert-BytesToGB {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    return [math]::Round(([double]$Value / 1GB), 2)
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message 'Platform script started.'

    $preferences = if (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue) { Get-MpPreference } else { $null }
    $ruleIds = if ($null -ne $preferences) { ConvertTo-StringArray -Value $preferences.AttackSurfaceReductionRules_Ids } else { @() }
    $ruleActions = if ($null -ne $preferences) { ConvertTo-StringArray -Value $preferences.AttackSurfaceReductionRules_Actions } else { @() }
    $rules = for ($index = 0; $index -lt $ruleIds.Count; $index++) {
        $id = $ruleIds[$index]
        [pscustomobject]@{
            Id = $id
            Action = if ($index -lt $ruleActions.Count) { $ruleActions[$index] } else { '' }
            KnownName = if ($KnownASRRuleNames.ContainsKey($id)) { $KnownASRRuleNames[$id] } else { '' }
        }
    }

    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        CapturedAt = (Get-Date).ToString('o')
        DefenderCmdletsAvailable = ($null -ne $preferences)
        Rules = @($rules)
    }

    if ($null -eq $payload) {
        throw 'The script did not create an output payload.'
    }

    $outputPath = Join-Path -Path $OutputRoot -ChildPath $OutputFileName
    $payload | ConvertTo-Json -Depth $JsonDepth | Set-Content -LiteralPath $outputPath -Encoding UTF8

    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw "Output file '$outputPath' was not created."
    }

    Write-Log -Message "Platform script completed. Output='$outputPath'."
    Write-Output "ASR rule state exported to '$outputPath'."
    exit 0
}
catch {
    try {
        Write-Log -Message "Platform script failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'ASR rule state export failed.'
    exit 1
}

