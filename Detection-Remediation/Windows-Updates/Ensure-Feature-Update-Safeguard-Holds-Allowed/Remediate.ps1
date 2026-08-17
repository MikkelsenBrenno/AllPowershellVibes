<#
.SYNOPSIS
    Allows Windows Update feature update safeguard holds.

.DESCRIPTION
    Intune Remediations remediation script. The script can remove or set the
    DisableWUfBSafeguards policy value so feature update safeguard holds are
    not bypassed. It is report-only by default.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation completed or report-only mode completed
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

$ScriptPackageName = 'Ensure-Feature-Update-Safeguard-Holds-Allowed'
$ScriptName = 'Remediate'

$WindowsUpdatePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$SafeguardPolicyValueName = 'DisableWUfBSafeguards'
$RemediationAction = 'SetZero'
$ApplyPolicyChange = $false

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
    Write-Log -Message "Remediation started. ApplyPolicyChange='$ApplyPolicyChange'; RemediationAction='$RemediationAction'."

    if (-not $ApplyPolicyChange) {
        Write-Output "Report-only mode. Would apply '$RemediationAction' for '$WindowsUpdatePolicyPath\$SafeguardPolicyValueName'."
        exit 0
    }

    if (-not (Test-Path -LiteralPath $WindowsUpdatePolicyPath)) {
        New-Item -Path $WindowsUpdatePolicyPath -Force | Out-Null
    }

    switch ($RemediationAction) {
        'SetZero' {
            New-ItemProperty -LiteralPath $WindowsUpdatePolicyPath -Name $SafeguardPolicyValueName -PropertyType DWord -Value 0 -Force | Out-Null
        }
        'RemoveValue' {
            Remove-ItemProperty -LiteralPath $WindowsUpdatePolicyPath -Name $SafeguardPolicyValueName -ErrorAction SilentlyContinue
        }
        default {
            throw "Unsupported RemediationAction '$RemediationAction'. Use SetZero or RemoveValue."
        }
    }

    Write-Output 'Remediation completed. Windows Update safeguard hold policy was updated.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Windows Update safeguard hold policy was not changed.'
    exit 1
}
