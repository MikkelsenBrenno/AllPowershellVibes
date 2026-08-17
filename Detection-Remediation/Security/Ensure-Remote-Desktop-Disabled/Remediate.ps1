<#
.SYNOPSIS
    Disables Remote Desktop.

.DESCRIPTION
    Intune Remediations remediation script. The script writes the Remote
    Desktop registry setting and can optionally disable Remote Desktop firewall
    rules after ApplyPolicy is enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remote Desktop is disabled
    Exit 1:      Remote Desktop remains enabled or remediation is disabled

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

$ScriptPackageName = 'Ensure-Remote-Desktop-Disabled'
$ScriptName = 'Remediate'

$TerminalServerRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
$DenyConnectionsValueName = 'fDenyTSConnections'
$DenyConnectionsValue = 1
$DisableFirewallRules = $false
$RemoteDesktopFirewallDisplayGroup = 'Remote Desktop'
$ApplyPolicy = $false
$ExitZeroInReportingOnlyMode = $false

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not $ApplyPolicy) {
        Write-Output 'Remote Desktop would be disabled, but ApplyPolicy is disabled.'
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    New-ItemProperty -Path $TerminalServerRegistryPath -Name $DenyConnectionsValueName -Value $DenyConnectionsValue -PropertyType DWord -Force | Out-Null

    if ($DisableFirewallRules) {
        Get-NetFirewallRule -DisplayGroup $RemoteDesktopFirewallDisplayGroup -ErrorAction SilentlyContinue |
            Disable-NetFirewallRule -ErrorAction SilentlyContinue
    }

    $terminalServer = Get-ItemProperty -LiteralPath $TerminalServerRegistryPath -Name $DenyConnectionsValueName -ErrorAction Stop
    if ([int]$terminalServer.$DenyConnectionsValueName -ne $DenyConnectionsValue) {
        throw "$DenyConnectionsValueName was not set to '$DenyConnectionsValue'."
    }

    Write-Output 'Remote Desktop policy was configured to deny connections.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed while disabling Remote Desktop.'
    exit 1
}
