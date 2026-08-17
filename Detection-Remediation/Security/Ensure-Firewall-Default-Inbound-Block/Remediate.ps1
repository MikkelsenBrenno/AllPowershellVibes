<#
.SYNOPSIS
    Sets Windows Firewall default inbound action to block.

.DESCRIPTION
    Intune Remediations remediation script. The script can configure the
    default inbound action for selected Windows Firewall profiles and validate
    the result. It starts in report-only mode so administrators can confirm
    policy ownership before enforcement.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation succeeded
    Exit 1:      Remediation failed or report-only mode is enabled

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
$ScriptName = 'Remediate'

# Choose one or more of: Domain, Private, Public.
$FirewallProfiles = @('Domain', 'Private', 'Public')

# Common expected value: Block.
$ExpectedDefaultInboundAction = 'Block'

# Keep report-only mode enabled until the values are approved for your tenant.
$ApplyPolicy = $false
$ExitZeroInReportingOnlyMode = $false

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
    Write-Log -Message "Remediation started. FirewallProfiles='$($FirewallProfiles -join ',')'; ExpectedDefaultInboundAction='$ExpectedDefaultInboundAction'; ApplyPolicy='$ApplyPolicy'."

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

    if (-not (Get-Command -Name Set-NetFirewallProfile -ErrorAction SilentlyContinue)) {
        throw 'Set-NetFirewallProfile is not available on this device.'
    }

    if (-not $ApplyPolicy) {
        $message = 'Report-only mode. Set $ApplyPolicy to $true after pilot testing to change Windows Firewall default inbound action.'
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message

        if ($ExitZeroInReportingOnlyMode) {
            exit 0
        }

        exit 1
    }

    $before = Get-NetFirewallProfile -Name $FirewallProfiles

    foreach ($profile in $before) {
        Write-Log -Message "Before remediation: Profile '$($profile.Name)' DefaultInboundAction='$($profile.DefaultInboundAction)'."
    }

    Write-Log -Message "Setting DefaultInboundAction='$ExpectedDefaultInboundAction' for selected Windows Firewall profiles."
    Set-NetFirewallProfile -Profile $FirewallProfiles -DefaultInboundAction $ExpectedDefaultInboundAction

    Start-Sleep -Seconds $ValidationDelaySeconds

    $after = Get-NetFirewallProfile -Name $FirewallProfiles
    $nonCompliantProfiles = @()

    foreach ($profile in $after) {
        $actualAction = $profile.DefaultInboundAction.ToString()
        Write-Log -Message "After remediation: Profile '$($profile.Name)' DefaultInboundAction='$actualAction'."

        if ($actualAction -ne $ExpectedDefaultInboundAction) {
            $nonCompliantProfiles += "$($profile.Name)=$actualAction"
        }
    }

    if ($nonCompliantProfiles.Count -eq 0) {
        $message = "Remediation succeeded. Selected Windows Firewall profiles use DefaultInboundAction '$ExpectedDefaultInboundAction'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. Profiles with unexpected inbound action: $($nonCompliantProfiles -join ', ')."
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

    Write-Output 'Remediation failed for Windows Firewall default inbound action.'
    exit 1
}
