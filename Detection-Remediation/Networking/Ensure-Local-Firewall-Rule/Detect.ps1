<#
.SYNOPSIS
    Detects a local Windows Firewall rule.

.DESCRIPTION
    Intune Remediations detection script. The script checks a configurable
    firewall rule display name and validates key properties.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Firewall rule is compliant
    Exit 1:      Firewall rule is missing or incorrect

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
$ScriptName = 'Detect'

$RuleDisplayName = 'Contoso Example Inbound HTTPS'
$ExpectedEnabled = 'True'
$ExpectedDirection = 'Inbound'
$ExpectedAction = 'Allow'
$ExpectedProtocol = 'TCP'
$ExpectedLocalPort = '443'

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

    $rule = Get-NetFirewallRule -DisplayName $RuleDisplayName -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($null -eq $rule) {
        Write-Output "Not compliant. Firewall rule '$RuleDisplayName' is missing."
        exit 1
    }

    $portFilter = $rule | Get-NetFirewallPortFilter -ErrorAction SilentlyContinue
    $issues = New-Object System.Collections.Generic.List[string]

    if ([string]$rule.Enabled -ne $ExpectedEnabled) { $issues.Add("Enabled is '$($rule.Enabled)'") }
    if ([string]$rule.Direction -ne $ExpectedDirection) { $issues.Add("Direction is '$($rule.Direction)'") }
    if ([string]$rule.Action -ne $ExpectedAction) { $issues.Add("Action is '$($rule.Action)'") }
    if ($ExpectedProtocol -and [string]$portFilter.Protocol -ne $ExpectedProtocol) { $issues.Add("Protocol is '$($portFilter.Protocol)'") }
    if ($ExpectedLocalPort -and [string]$portFilter.LocalPort -ne $ExpectedLocalPort) { $issues.Add("LocalPort is '$($portFilter.LocalPort)'") }

    if ($issues.Count -eq 0) {
        Write-Output "Compliant. Firewall rule '$RuleDisplayName' matches expected settings."
        exit 0
    }

    Write-Output "Not compliant. Firewall rule '$RuleDisplayName' mismatch: $($issues -join '; ')."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. Firewall rule '$RuleDisplayName' could not be validated."
    exit 1
}
