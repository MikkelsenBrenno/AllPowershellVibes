<#
.SYNOPSIS
    Exports WinHTTP and user proxy state.

.DESCRIPTION
    Intune platform script for Microsoft 365 Business Premium environments.
    The script captures WinHTTP proxy output and common Internet Settings
    proxy values for troubleshooting Microsoft 365 connectivity.

.NOTES
    Name:        Export-WinHTTP-And-Proxy-State.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Platform Script
    Exit 0:      Proxy state exported
    Exit 1:      Proxy state export failed

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

$ScriptPackageName = 'Export-WinHTTP-And-Proxy-State'
$ScriptName = 'Export-WinHTTP-And-Proxy-State'

$OutputRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$OutputFileName = 'WinHTTPAndProxyState.json'
$NetshPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\netsh.exe'
$InternetSettingsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'

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

    $winHttpOutput = if (Test-Path -LiteralPath $NetshPath -PathType Leaf) { @(& $NetshPath winhttp show proxy 2>&1) } else { @('netsh.exe not found') }
    $internetSettings = if (Test-Path -LiteralPath $InternetSettingsPath) { Get-ItemProperty -LiteralPath $InternetSettingsPath -ErrorAction SilentlyContinue } else { $null }

    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        CapturedAt = (Get-Date).ToString('o')
        WinHttpProxyOutput = $winHttpOutput
        UserInternetSettingsPath = $InternetSettingsPath
        ProxyEnable = if ($null -ne $internetSettings) { $internetSettings.ProxyEnable } else { $null }
        ProxyServer = if ($null -ne $internetSettings) { [string]$internetSettings.ProxyServer } else { '' }
        AutoConfigURL = if ($null -ne $internetSettings) { [string]$internetSettings.AutoConfigURL } else { '' }
        ProxyOverride = if ($null -ne $internetSettings) { [string]$internetSettings.ProxyOverride } else { '' }
    }

    $outputPath = Join-Path -Path $OutputRoot -ChildPath $OutputFileName
    $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outputPath -Encoding UTF8
    Write-Log -Message "Proxy state exported to '$outputPath'."
    Write-Output "Proxy state exported to '$outputPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Proxy state export failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Proxy state export failed.'
    exit 1
}
