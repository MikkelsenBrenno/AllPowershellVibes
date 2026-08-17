<#
.SYNOPSIS
    Configures Windows Firewall logging.

.DESCRIPTION
    Intune Remediations remediation script. The script can configure firewall
    profile logging values. It is report-only by default so logging volume and
    file path can be piloted first.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation completed or report-only mode completed
    Exit 1:      Remediation failed

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

$ScriptPackageName = 'Ensure-Windows-Firewall-Logging-Enabled'
$ScriptName = 'Remediate'

$ProfilesToConfigure = @('Domain', 'Private', 'Public')
$SetBlockedLogging = $true
$SetAllowedLogging = $false
$LogMaxSizeKilobytes = 16384
$LogFileName = '%systemroot%\system32\LogFiles\Firewall\pfirewall.log'
$ApplyFirewallLoggingChange = $false

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

    if (-not (Get-Command -Name Set-NetFirewallProfile -ErrorAction SilentlyContinue)) {
        throw 'Set-NetFirewallProfile is not available on this device.'
    }

    if (-not $ApplyFirewallLoggingChange) {
        Write-Output "Report-only mode. Would configure firewall logging on profiles: $($ProfilesToConfigure -join ', ')."
        exit 0
    }

    foreach ($profileName in $ProfilesToConfigure) {
        Set-NetFirewallProfile -Name $profileName -LogBlocked $SetBlockedLogging -LogAllowed $SetAllowedLogging -LogMaxSizeKilobytes $LogMaxSizeKilobytes -LogFileName $LogFileName -ErrorAction Stop
        Write-Log -Message "Configured firewall logging for profile '$profileName'."
    }

    Write-Output 'Remediation completed. Windows Firewall logging was configured.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Windows Firewall logging was not configured.'
    exit 1
}
