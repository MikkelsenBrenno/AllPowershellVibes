<#
.SYNOPSIS
    Enables Windows Firewall for selected profiles.

.DESCRIPTION
    Intune Remediations remediation script. The script enables Windows
    Firewall for the configured profiles and validates that all selected
    profiles are enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation succeeded
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

# Keep these names aligned with the folder and script file.
# Logs are written to Logs\<ScriptPackageName>\<ScriptName>.log.
$ScriptPackageName = 'Firewall-Enable-All-Profiles'
$ScriptName = 'Remediate'

# Choose one or more of: Domain, Private, Public.
$FirewallProfiles = @('Domain', 'Private', 'Public')

# Increase this if policy or platform state needs more time before validation.
$ValidationDelaySeconds = 3

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
    Write-Log -Message "Remediation started. FirewallProfiles='$($FirewallProfiles -join ',')'."

    foreach ($profile in $FirewallProfiles) {
        if ($profile -notin @('Domain', 'Private', 'Public')) {
            throw "Firewall profile '$profile' is not valid."
        }
    }

    if (-not (Get-Command -Name Get-NetFirewallProfile -ErrorAction SilentlyContinue)) {
        throw 'Get-NetFirewallProfile is not available on this device.'
    }

    if (-not (Get-Command -Name Set-NetFirewallProfile -ErrorAction SilentlyContinue)) {
        throw 'Set-NetFirewallProfile is not available on this device.'
    }

    $before = Get-NetFirewallProfile -Name $FirewallProfiles

    foreach ($profile in $before) {
        Write-Log -Message "Before remediation: Profile '$($profile.Name)' Enabled='$($profile.Enabled)'."
    }

    Write-Log -Message "Enabling selected Windows Firewall profiles."
    Set-NetFirewallProfile -Profile $FirewallProfiles -Enabled True

    Start-Sleep -Seconds $ValidationDelaySeconds

    $after = Get-NetFirewallProfile -Name $FirewallProfiles
    $nonCompliantProfiles = @()

    foreach ($profile in $after) {
        Write-Log -Message "After remediation: Profile '$($profile.Name)' Enabled='$($profile.Enabled)'."

        if ($profile.Enabled.ToString() -ne 'True') {
            $nonCompliantProfiles += $profile.Name
        }
    }

    if ($nonCompliantProfiles.Count -eq 0) {
        $message = "Remediation succeeded. Selected Windows Firewall profiles are enabled: $($FirewallProfiles -join ', ')."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. Disabled Windows Firewall profiles: $($nonCompliantProfiles -join ', ')."
    Write-Log -Message $message -Level 'ERROR'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Remediation failed for Windows Firewall profiles.'
    exit 1
}

