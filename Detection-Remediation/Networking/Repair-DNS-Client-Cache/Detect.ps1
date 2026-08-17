<#
.SYNOPSIS
    Detects DNS resolution for a configured hostname.

.DESCRIPTION
    Intune Remediations detection script. The script attempts to resolve a
    configured hostname and exits 1 when remediation should clear the local DNS
    cache.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      DNS resolution succeeded
    Exit 1:      DNS resolution failed

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

$ScriptPackageName = 'Repair-DNS-Client-Cache'
$ScriptName = 'Detect'

$HostnameToResolve = 'login.microsoftonline.com'
$DnsQueryType = 'A'

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

    if (-not (Get-Command -Name Resolve-DnsName -ErrorAction SilentlyContinue)) {
        throw 'Resolve-DnsName is not available on this device.'
    }

    $records = @(Resolve-DnsName -Name $HostnameToResolve -Type $DnsQueryType -ErrorAction Stop)
    Write-Log -Message "Resolved '$HostnameToResolve' with '$($records.Count)' record(s)."

    if ($records.Count -gt 0) {
        Write-Output "Compliant. DNS resolution succeeded for '$HostnameToResolve'."
        exit 0
    }

    Write-Output "Not compliant. DNS resolution returned no records for '$HostnameToResolve'."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. DNS resolution failed for '$HostnameToResolve'."
    exit 1
}
