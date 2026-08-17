<#
.SYNOPSIS
    Detects whether Windows Firewall default inbound action is blocked.

.DESCRIPTION
    Intune Remediations detection script. The script checks the default
    inbound action for selected Windows Firewall profiles and exits 0 when all
    selected profiles use the expected action. It exits 1 when remediation
    should run.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Selected firewall profiles use the expected inbound action
    Exit 1:      One or more selected profiles use a different inbound action

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
$ScriptPackageName = 'Ensure-Firewall-Default-Inbound-Block'
$ScriptName = 'Detect'

# Choose one or more of: Domain, Private, Public.
$FirewallProfiles = @('Domain', 'Private', 'Public')

# Common expected value: Block.
$ExpectedDefaultInboundAction = 'Block'

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
    Write-Log -Message "Detection started. FirewallProfiles='$($FirewallProfiles -join ',')'; ExpectedDefaultInboundAction='$ExpectedDefaultInboundAction'."

    foreach ($profile in $FirewallProfiles) {
        if ($profile -notin @('Domain', 'Private', 'Public')) {
            throw "Firewall profile '$profile' is not valid."
        }
    }

    if ($ExpectedDefaultInboundAction -notin @('Allow', 'Block', 'NotConfigured')) {
        throw "ExpectedDefaultInboundAction '$ExpectedDefaultInboundAction' is not valid."
    }

    if (-not (Get-Command -Name Get-NetFirewallProfile -ErrorAction SilentlyContinue)) {
        throw 'Get-NetFirewallProfile is not available on this device.'
    }

    $profiles = Get-NetFirewallProfile -Name $FirewallProfiles
    $nonCompliantProfiles = @()

    foreach ($profile in $profiles) {
        $actualAction = $profile.DefaultInboundAction.ToString()
        Write-Log -Message "Profile '$($profile.Name)' DefaultInboundAction='$actualAction'."

        if ($actualAction -ne $ExpectedDefaultInboundAction) {
            $nonCompliantProfiles += "$($profile.Name)=$actualAction"
        }
    }

    if ($nonCompliantProfiles.Count -eq 0) {
        $message = "Compliant. Selected Windows Firewall profiles use DefaultInboundAction '$ExpectedDefaultInboundAction'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Profiles with unexpected inbound action: $($nonCompliantProfiles -join ', ')."
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

    Write-Output 'Not compliant. Windows Firewall default inbound action could not be validated.'
    exit 1
}
