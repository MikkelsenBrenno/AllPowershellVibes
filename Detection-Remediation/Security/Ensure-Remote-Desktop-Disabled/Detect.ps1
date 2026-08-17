<#
.SYNOPSIS
    Detects whether Remote Desktop is disabled.

.DESCRIPTION
    Intune Remediations detection script. The script checks the Remote Desktop
    registry setting and can optionally check Remote Desktop firewall rules.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remote Desktop is disabled
    Exit 1:      Remote Desktop appears enabled

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
$ScriptName = 'Detect'

$TerminalServerRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
$DenyConnectionsValueName = 'fDenyTSConnections'
$ExpectedDenyConnectionsValue = 1
$CheckFirewallRules = $false
$RemoteDesktopFirewallDisplayGroup = 'Remote Desktop'

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
    $issues = New-Object System.Collections.Generic.List[string]
    $terminalServer = Get-ItemProperty -LiteralPath $TerminalServerRegistryPath -Name $DenyConnectionsValueName -ErrorAction Stop
    $actualDenyConnections = [int]$terminalServer.$DenyConnectionsValueName

    if ($actualDenyConnections -ne $ExpectedDenyConnectionsValue) {
        $issues.Add("$DenyConnectionsValueName is '$actualDenyConnections'")
    }

    if ($CheckFirewallRules) {
        $enabledRules = @(Get-NetFirewallRule -DisplayGroup $RemoteDesktopFirewallDisplayGroup -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq 'True' })
        if ($enabledRules.Count -gt 0) {
            $issues.Add("$($enabledRules.Count) Remote Desktop firewall rule(s) enabled")
        }
    }

    if ($issues.Count -eq 0) {
        Write-Output 'Compliant. Remote Desktop appears disabled.'
        exit 0
    }

    Write-Output "Not compliant. $($issues -join '; ')."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Remote Desktop state could not be validated.'
    exit 1
}
