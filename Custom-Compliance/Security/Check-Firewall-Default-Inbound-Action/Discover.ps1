<#
.SYNOPSIS
    Discovers Windows Firewall default inbound action.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks the default
    inbound action for selected Windows Firewall profiles and returns one
    compressed JSON object.

.NOTES
    Name:        Discover.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Custom Compliance
    Output:      Compressed JSON

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

$ScriptPackageName = 'Check-Firewall-Default-Inbound-Action'
$ScriptName = 'Discover'

$FirewallProfiles = @('Domain', 'Private', 'Public')
$ExpectedDefaultInboundAction = 'Block'

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

$result = [ordered]@{
    FirewallDefaultInboundCompliant = $false
    ExpectedDefaultInboundAction = $ExpectedDefaultInboundAction
    NonCompliantProfiles = @()
    Profiles = @()
}

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Get-Command -Name Get-NetFirewallProfile -ErrorAction SilentlyContinue)) {
        throw 'Get-NetFirewallProfile is not available on this device.'
    }

    foreach ($profile in $FirewallProfiles) {
        if ($profile -notin @('Domain', 'Private', 'Public')) {
            throw "Firewall profile '$profile' is not valid."
        }
    }

    $profiles = @(Get-NetFirewallProfile -Name $FirewallProfiles -ErrorAction Stop)
    $profileResults = foreach ($profile in $profiles) {
        $actualInboundAction = [string]$profile.DefaultInboundAction
        $isCompliant = ($actualInboundAction -eq $ExpectedDefaultInboundAction)

        if (-not $isCompliant) {
            $result.NonCompliantProfiles += [string]$profile.Name
        }

        [PSCustomObject]@{
            Name = [string]$profile.Name
            Enabled = [string]$profile.Enabled
            DefaultInboundAction = $actualInboundAction
            Compliant = [bool]$isCompliant
        }
    }

    $result.Profiles = @($profileResults)
    $result.FirewallDefaultInboundCompliant = ($result.NonCompliantProfiles.Count -eq 0)

    Write-Log -Message "Discovery completed. NonCompliantProfiles='$($result.NonCompliantProfiles -join ',')'; Compliant='$($result.FirewallDefaultInboundCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.FirewallDefaultInboundCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
