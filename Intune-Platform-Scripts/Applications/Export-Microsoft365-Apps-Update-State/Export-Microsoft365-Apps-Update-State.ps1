<#
.SYNOPSIS
    Exports Microsoft 365 Apps Click-to-Run update state.

.DESCRIPTION
    Intune platform script for Microsoft 365 Business Premium environments.
    The script reads Microsoft 365 Apps Click-to-Run configuration values and
    writes them to JSON for troubleshooting update channel drift.

.NOTES
    Name:        Export-Microsoft365-Apps-Update-State.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Platform Script
    Exit 0:      Microsoft 365 Apps update state exported
    Exit 1:      Microsoft 365 Apps update state export failed

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

$ScriptPackageName = 'Export-Microsoft365-Apps-Update-State'
$ScriptName = 'Export-Microsoft365-Apps-Update-State'

$ClickToRunConfigurationPath = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'
$OutputRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$OutputFileName = 'Microsoft365AppsUpdateState.json'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }; if (-not (Test-Path -LiteralPath $OutputRoot)) { New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $configuration = if (Test-Path -LiteralPath $ClickToRunConfigurationPath) { Get-ItemProperty -LiteralPath $ClickToRunConfigurationPath -ErrorAction Stop } else { $null }
    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        CapturedAt = (Get-Date).ToString('o')
        ClickToRunConfigurationPath = $ClickToRunConfigurationPath
        ConfigurationFound = ($null -ne $configuration)
        ClientVersionToReport = if ($null -ne $configuration) { [string]$configuration.ClientVersionToReport } else { '' }
        VersionToReport = if ($null -ne $configuration) { [string]$configuration.VersionToReport } else { '' }
        CDNBaseUrl = if ($null -ne $configuration) { [string]$configuration.CDNBaseUrl } else { '' }
        UpdateChannel = if ($null -ne $configuration) { [string]$configuration.UpdateChannel } else { '' }
        UpdatesEnabled = if ($null -ne $configuration) { [string]$configuration.UpdatesEnabled } else { '' }
        Platform = if ($null -ne $configuration) { [string]$configuration.Platform } else { '' }
        ProductReleaseIds = if ($null -ne $configuration) { [string]$configuration.ProductReleaseIds } else { '' }
    }

    $outputPath = Join-Path -Path $OutputRoot -ChildPath $OutputFileName
    $payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $outputPath -Encoding UTF8
    Write-Log -Message "Microsoft 365 Apps update state exported to '$outputPath'."
    Write-Output "Microsoft 365 Apps update state exported to '$outputPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Microsoft 365 Apps update state export failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Microsoft 365 Apps update state export failed.'
    exit 1
}
