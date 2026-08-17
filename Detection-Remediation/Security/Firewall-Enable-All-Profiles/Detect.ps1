<#
.SYNOPSIS
    Detects whether Windows Firewall is enabled for selected profiles.

.DESCRIPTION
    Intune Remediations detection script. The script checks Windows Firewall
    profile state for the configured profiles and exits 0 when all selected
    profiles are enabled. It exits 1 when remediation should run.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Selected firewall profiles are enabled
    Exit 1:      One or more selected firewall profiles are disabled or unavailable

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

# Keep these names aligned with the folder and script file.
# Logs are written to Logs\<ScriptPackageName>\<ScriptName>.log.
$ScriptPackageName = 'Firewall-Enable-All-Profiles'
$ScriptName = 'Detect'

# Choose one or more of: Domain, Private, Public.
$FirewallProfiles = @('Domain', 'Private', 'Public')

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. FirewallProfiles='$($FirewallProfiles -join ',')'."

    foreach ($profile in $FirewallProfiles) {
        if ($profile -notin @('Domain', 'Private', 'Public')) {
            throw "Firewall profile '$profile' is not valid."
        }
    }

    if (-not (Get-Command -Name Get-NetFirewallProfile -ErrorAction SilentlyContinue)) {
        throw 'Get-NetFirewallProfile is not available on this device.'
    }

    $profiles = Get-NetFirewallProfile -Name $FirewallProfiles
    $nonCompliantProfiles = @()

    foreach ($profile in $profiles) {
        Write-Log -Message "Profile '$($profile.Name)' Enabled='$($profile.Enabled)'."

        if ($profile.Enabled.ToString() -ne 'True') {
            $nonCompliantProfiles += $profile.Name
        }
    }

    if ($nonCompliantProfiles.Count -eq 0) {
        $message = "Compliant. Selected Windows Firewall profiles are enabled: $($FirewallProfiles -join ', ')."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Disabled Windows Firewall profiles: $($nonCompliantProfiles -join ', ')."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Not compliant. Windows Firewall profile state could not be validated.'
    exit 1
}

