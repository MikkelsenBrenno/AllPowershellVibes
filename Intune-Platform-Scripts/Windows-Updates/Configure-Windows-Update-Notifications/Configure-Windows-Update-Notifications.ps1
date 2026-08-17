<#
.SYNOPSIS
    Configures Windows Update notification display policy values.

.DESCRIPTION
    Intune platform script example. By default, the script removes Windows
    Update notification display policy values so default notifications apply.

.NOTES
    Name:        Configure-Windows-Update-Notifications.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Windows Update notification policy was configured
    Exit 1:      Windows Update notification policy could not be configured

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

$ScriptPackageName = 'Configure-Windows-Update-Notifications'
$ScriptName = 'Configure-Windows-Update-Notifications'

$WindowsUpdatePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'

# Choose one: DefaultNotifications, RestartWarningsOnly, DisableAllNotifications.
$NotificationDisplayOption = 'DefaultNotifications'

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
    Write-Log -Message "Script started. NotificationDisplayOption='$NotificationDisplayOption'."
    if (-not (Test-Path -LiteralPath $WindowsUpdatePolicyPath)) { New-Item -Path $WindowsUpdatePolicyPath -ItemType Directory -Force | Out-Null }

    if ($NotificationDisplayOption -eq 'DefaultNotifications') {
        Remove-ItemProperty -LiteralPath $WindowsUpdatePolicyPath -Name 'SetUpdateNotificationLevel' -ErrorAction SilentlyContinue
        Remove-ItemProperty -LiteralPath $WindowsUpdatePolicyPath -Name 'UpdateNotificationLevel' -ErrorAction SilentlyContinue
    }
    else {
        $levelMap = @{ RestartWarningsOnly = 1; DisableAllNotifications = 2 }
        if (-not $levelMap.ContainsKey($NotificationDisplayOption)) { throw "NotificationDisplayOption '$NotificationDisplayOption' is not valid." }
        New-ItemProperty -Path $WindowsUpdatePolicyPath -Name 'SetUpdateNotificationLevel' -Value 1 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $WindowsUpdatePolicyPath -Name 'UpdateNotificationLevel' -Value $levelMap[$NotificationDisplayOption] -PropertyType DWord -Force | Out-Null
    }

    Write-Output "Windows Update notification policy configured: $NotificationDisplayOption."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to configure Windows Update notifications.'
    exit 1
}
