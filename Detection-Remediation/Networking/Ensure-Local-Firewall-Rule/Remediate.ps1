<#
.SYNOPSIS
    Creates or updates a local Windows Firewall rule.

.DESCRIPTION
    Intune Remediations remediation script. Creation/update is disabled by
    default so technicians can confirm the rule before changing firewall
    state.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Firewall rule is compliant
    Exit 1:      Firewall rule remains noncompliant

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

$ScriptPackageName = 'Ensure-Local-Firewall-Rule'
$ScriptName = 'Remediate'

$RuleDisplayName = 'Contoso Example Inbound HTTPS'
$RuleDescription = 'Example inbound firewall rule. Customize before deployment.'
$Direction = 'Inbound'
$Action = 'Allow'
$Protocol = 'TCP'
$LocalPort = '443'
$Profile = 'Domain,Private'
$CreateOrUpdateRule = $false
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

    if (-not $CreateOrUpdateRule) {
        Write-Output "Firewall rule '$RuleDisplayName' would be created or updated, but CreateOrUpdateRule is disabled."
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    $rule = Get-NetFirewallRule -DisplayName $RuleDisplayName -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($null -eq $rule) {
        New-NetFirewallRule -DisplayName $RuleDisplayName -Description $RuleDescription -Direction $Direction -Action $Action -Protocol $Protocol -LocalPort $LocalPort -Profile $Profile -Enabled True -ErrorAction Stop | Out-Null
    }
    else {
        Set-NetFirewallRule -DisplayName $RuleDisplayName -Description $RuleDescription -Direction $Direction -Action $Action -Profile $Profile -Enabled True -ErrorAction Stop
        Set-NetFirewallPortFilter -AssociatedNetFirewallRule $rule -Protocol $Protocol -LocalPort $LocalPort -ErrorAction Stop
    }

    Write-Output "Firewall rule '$RuleDisplayName' created or updated."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation failed for firewall rule '$RuleDisplayName'."
    exit 1
}
