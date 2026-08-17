<#
.SYNOPSIS
    Detects whether Windows Firewall logging is enabled.

.DESCRIPTION
    Intune Remediations detection script. The script checks configurable
    firewall profiles for blocked packet logging, allowed packet logging, log
    file path, and maximum log size.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Firewall logging matches expected values
    Exit 1:      Firewall logging is missing or different

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
$ScriptName = 'Detect'

$ProfilesToCheck = @('Domain', 'Private', 'Public')
$RequireBlockedLogging = $true
$RequireAllowedLogging = $false
$MinimumLogMaxSizeKilobytes = 16384
$ExpectedLogFileName = '%systemroot%\system32\LogFiles\Firewall\pfirewall.log'

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

    if (-not (Get-Command -Name Get-NetFirewallProfile -ErrorAction SilentlyContinue)) {
        throw 'Get-NetFirewallProfile is not available on this device.'
    }

    $nonCompliant = @()
    foreach ($profileName in $ProfilesToCheck) {
        $profile = Get-NetFirewallProfile -Name $profileName -ErrorAction Stop

        if ($RequireBlockedLogging -and $profile.LogBlocked -ne 'True') {
            $nonCompliant += "$profileName LogBlocked=$($profile.LogBlocked)"
        }

        if ($RequireAllowedLogging -and $profile.LogAllowed -ne 'True') {
            $nonCompliant += "$profileName LogAllowed=$($profile.LogAllowed)"
        }

        if ([int]$profile.LogMaxSizeKilobytes -lt $MinimumLogMaxSizeKilobytes) {
            $nonCompliant += "$profileName LogMaxSizeKilobytes=$($profile.LogMaxSizeKilobytes)"
        }

        if ($profile.LogFileName -ne $ExpectedLogFileName) {
            $nonCompliant += "$profileName LogFileName=$($profile.LogFileName)"
        }
    }

    if ($nonCompliant.Count -eq 0) {
        $message = 'Compliant. Windows Firewall logging matches expected values.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Firewall logging differences: $($nonCompliant -join '; ')."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Windows Firewall logging could not be validated.'
    exit 1
}
