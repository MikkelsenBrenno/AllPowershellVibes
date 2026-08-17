<#
.SYNOPSIS
    Detects whether Windows Update safeguard holds are allowed.

.DESCRIPTION
    Intune Remediations detection script. The script checks the
    DisableWUfBSafeguards policy value and reports noncompliance when safeguard
    holds are disabled.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Safeguard holds are allowed
    Exit 1:      Safeguard holds are disabled

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
$ScriptName = 'Detect'

$WindowsUpdatePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
$SafeguardPolicyValueName = 'DisableWUfBSafeguards'
$NonCompliantValue = 1

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

    $properties = Get-ItemProperty -LiteralPath $WindowsUpdatePolicyPath -Name $SafeguardPolicyValueName -ErrorAction SilentlyContinue
    $currentValue = $null

    if ($null -ne $properties -and $null -ne $properties.$SafeguardPolicyValueName) {
        $currentValue = [int]$properties.$SafeguardPolicyValueName
    }

    if ($currentValue -ne $NonCompliantValue) {
        $message = "Compliant. Safeguard hold override value is '$currentValue'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Safeguard holds are disabled by '$SafeguardPolicyValueName=$currentValue'."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Windows Update safeguard hold policy could not be validated.'
    exit 1
}
