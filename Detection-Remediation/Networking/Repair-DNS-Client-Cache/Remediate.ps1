<#
.SYNOPSIS
    Clears the local DNS client cache.

.DESCRIPTION
    Intune Remediations remediation script. The script clears the local DNS
    client cache and optionally registers DNS records, then validates
    resolution for the configured hostname.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      DNS repair succeeded
    Exit 1:      DNS repair failed

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
$ScriptName = 'Remediate'

$HostnameToResolve = 'login.microsoftonline.com'
$DnsQueryType = 'A'
$RegisterDnsAfterFlush = $false
$ValidationDelaySeconds = 3

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

    if (Get-Command -Name Clear-DnsClientCache -ErrorAction SilentlyContinue) {
        Clear-DnsClientCache
    }
    elseif (Get-Command -Name ipconfig.exe -ErrorAction SilentlyContinue) {
        & ipconfig.exe /flushdns | Out-Null
    }
    else {
        throw 'No DNS cache clearing command is available on this device.'
    }

    if ($RegisterDnsAfterFlush -and (Get-Command -Name ipconfig.exe -ErrorAction SilentlyContinue)) {
        & ipconfig.exe /registerdns | Out-Null
    }

    Start-Sleep -Seconds $ValidationDelaySeconds
    $records = @(Resolve-DnsName -Name $HostnameToResolve -Type $DnsQueryType -ErrorAction Stop)

    if ($records.Count -gt 0) {
        Write-Output "Remediation succeeded. DNS resolution succeeded for '$HostnameToResolve'."
        exit 0
    }

    throw "DNS resolution returned no records for '$HostnameToResolve'."
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation failed for DNS resolution of '$HostnameToResolve'."
    exit 1
}
