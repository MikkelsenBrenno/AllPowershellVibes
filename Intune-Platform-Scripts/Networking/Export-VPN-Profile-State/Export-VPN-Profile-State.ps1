<#
.SYNOPSIS
    Exports VPN profile state.

.DESCRIPTION
    Intune platform script that reads Windows VPN connection details through Get-VpnConnection when available.

.NOTES
    Name:        Export-VPN-Profile-State.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune Platform Script
    Exit 0:      VPN profile state exported
    Exit 1:      VPN profile export failed

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
$ScriptPackageName = 'Export-VPN-Profile-State'
$ScriptName = 'Export-VPN-Profile-State'

$OutputRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$OutputFileName = 'VPNProfileState.json'
$JsonDepth = 8

$ExpectedVpnProfileNames = @('Contoso VPN')
$IncludeAllUserConnections = $true

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

    $vpnConnections = @()
    if (Get-Command -Name Get-VpnConnection -ErrorAction SilentlyContinue) {
        foreach ($name in $ExpectedVpnProfileNames) {
            $vpnConnections += @(Get-VpnConnection -Name $name -AllUserConnection:$IncludeAllUserConnections -ErrorAction SilentlyContinue | Select-Object Name, ServerAddress, TunnelType, SplitTunneling, AllUserConnection, ConnectionStatus, RememberCredential)
        }
    }
    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        CapturedAt = (Get-Date).ToString('o')
        ExpectedVpnProfileNames = $ExpectedVpnProfileNames
        IncludeAllUserConnections = $IncludeAllUserConnections
        VpnCmdletsAvailable = [bool](Get-Command -Name Get-VpnConnection -ErrorAction SilentlyContinue)
        VpnConnections = @($vpnConnections)
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
    Write-Output "VPN profile state exported to '$outputPath'."
    exit 0
}
catch {
    try {
        Write-Log -Message "Platform script failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'VPN profile export failed.'
    exit 1
}

