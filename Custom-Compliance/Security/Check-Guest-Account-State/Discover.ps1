<#
.SYNOPSIS
    Discovers built-in Guest account state for custom compliance.

.DESCRIPTION
    Intune custom compliance discovery script. The script locates the built-in
    local Guest account by SID ending in -501 and returns one compressed JSON
    object with the enabled/disabled state.

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

$ScriptPackageName = 'Check-Guest-Account-State'
$ScriptName = 'Discover'

$GuestSidSuffix = '-501'
$ExpectedGuestEnabledState = $false

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
    GuestAccountCompliant = $false
    GuestAccountExists = $false
    GuestAccountName = ''
    GuestAccountSid = ''
    GuestAccountEnabled = $false
    ExpectedGuestEnabledState = [bool]$ExpectedGuestEnabledState
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $guestAccount = Get-CimInstance -ClassName Win32_UserAccount -Filter 'LocalAccount=True' -ErrorAction Stop |
        Where-Object { [string]$_.SID -like "*$GuestSidSuffix" } |
        Select-Object -First 1

    if ($null -eq $guestAccount) {
        throw "Built-in Guest account with SID suffix '$GuestSidSuffix' was not found."
    }

    $enabled = -not [bool]$guestAccount.Disabled

    $result.GuestAccountExists = $true
    $result.GuestAccountName = [string]$guestAccount.Name
    $result.GuestAccountSid = [string]$guestAccount.SID
    $result.GuestAccountEnabled = [bool]$enabled
    $result.GuestAccountCompliant = ($result.GuestAccountEnabled -eq $ExpectedGuestEnabledState)

    Write-Log -Message "Discovery completed. GuestName='$($result.GuestAccountName)'; Enabled='$($result.GuestAccountEnabled)'; Expected='$ExpectedGuestEnabledState'; Compliant='$($result.GuestAccountCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.GuestAccountCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
