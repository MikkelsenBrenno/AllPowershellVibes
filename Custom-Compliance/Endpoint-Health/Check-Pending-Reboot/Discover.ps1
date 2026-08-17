<#
.SYNOPSIS
    Discovers whether Windows has a pending reboot.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks common
    Windows pending reboot registry locations and returns one compressed
    JSON object.

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

$ScriptPackageName = 'Check-Pending-Reboot'
$ScriptName = 'Discover'

$CheckComponentBasedServicing = $true
$CheckWindowsUpdate = $true
$CheckPendingFileRenameOperations = $true

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
    PendingReboot = $false
    PendingRebootReasons = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata
    $reasons = New-Object System.Collections.Generic.List[string]

    if ($CheckComponentBasedServicing -and (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')) { $reasons.Add('ComponentBasedServicing') }
    if ($CheckWindowsUpdate -and (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')) { $reasons.Add('WindowsUpdate') }
    if ($CheckPendingFileRenameOperations) {
        $sessionManager = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
        if ($null -ne $sessionManager -and $null -ne $sessionManager.PendingFileRenameOperations) { $reasons.Add('PendingFileRenameOperations') }
    }

    $result.PendingReboot = ($reasons.Count -gt 0)
    $result.PendingRebootReasons = ($reasons -join ',')
    Write-Log -Message "Discovery completed. PendingReboot='$($result.PendingReboot)'; Reasons='$($result.PendingRebootReasons)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.PendingReboot = $true
    $result.PendingRebootReasons = 'Error'
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
