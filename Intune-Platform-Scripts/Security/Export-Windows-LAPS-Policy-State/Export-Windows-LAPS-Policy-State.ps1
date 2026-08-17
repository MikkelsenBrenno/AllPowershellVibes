<#
.SYNOPSIS
    Exports Windows LAPS policy state.

.DESCRIPTION
    Intune platform script that reads Windows LAPS policy registry values useful for Business Premium account protection troubleshooting.

.NOTES
    Name:        Export-Windows-LAPS-Policy-State.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune Platform Script
    Exit 0:      Windows LAPS policy state exported
    Exit 1:      Windows LAPS policy export failed

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
$ScriptPackageName = 'Export-Windows-LAPS-Policy-State'
$ScriptName = 'Export-Windows-LAPS-Policy-State'

$OutputRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$OutputFileName = 'WindowsLAPSPolicyState.json'
$JsonDepth = 8

$LapsPolicyValues = @(
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Policies\LAPS'; Name = 'BackupDirectory'; Description = 'Where the local admin password is backed up' },
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Policies\LAPS'; Name = 'PasswordAgeDays'; Description = 'Maximum password age in days' },
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Policies\LAPS'; Name = 'AdministratorAccountName'; Description = 'Managed local administrator account name' },
    @{ Path = 'HKLM:\SOFTWARE\Microsoft\Policies\LAPS'; Name = 'PostAuthenticationActions'; Description = 'Post-authentication action policy' }
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

    $policyState = @(Get-RegistrySnapshot -Items $LapsPolicyValues)
    $lapsModule = Get-Module -ListAvailable -Name LAPS -ErrorAction SilentlyContinue
    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        CapturedAt = (Get-Date).ToString('o')
        PolicyState = $policyState
        LapsModuleAvailable = ($null -ne $lapsModule)
        LapsCommands = if ($null -ne $lapsModule) { @(Get-Command -Module LAPS -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name) } else { @() }
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
    Write-Output "Windows LAPS policy state exported to '$outputPath'."
    exit 0
}
catch {
    try {
        Write-Log -Message "Platform script failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Windows LAPS policy export failed.'
    exit 1
}

