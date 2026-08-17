<#
.SYNOPSIS
    Discovers whether Windows Update or servicing is waiting for a reboot.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks common reboot
    pending registry locations and returns compressed JSON for custom
    compliance.

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

$ScriptPackageName = 'Check-Windows-Update-Pending-Reboot'
$ScriptName = 'Discover'

$RebootRequiredPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
    'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
)
$PendingFileRenameValueName = 'PendingFileRenameOperations'

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
    NoWindowsUpdatePendingReboot = $false
    PendingReboot = $false
    MatchedSignals = @()
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $signals = @()

    foreach ($path in $RebootRequiredPaths) {
        if (Test-Path -LiteralPath $path) {
            if ($path -like '*Session Manager') {
                $sessionManager = Get-ItemProperty -LiteralPath $path -ErrorAction SilentlyContinue
                if ($null -ne $sessionManager.$PendingFileRenameValueName) {
                    $signals += 'PendingFileRenameOperations'
                }
            }
            else {
                $signals += $path
            }
        }
    }

    $result.MatchedSignals = $signals
    $result.PendingReboot = ($signals.Count -gt 0)
    $result.NoWindowsUpdatePendingReboot = (-not $result.PendingReboot)

    Write-Log -Message "Discovery completed. PendingReboot='$($result.PendingReboot)'; Signals='$($signals -join ',')'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.NoWindowsUpdatePendingReboot = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
