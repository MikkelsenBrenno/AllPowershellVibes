<#
.SYNOPSIS
    Disables Windows Fast Startup.

.DESCRIPTION
    Intune Remediations remediation script. The script can set the
    HiberbootEnabled registry value to the configured target. It is report-only
    by default because some teams prefer to pilot power behavior first.

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

$ScriptPackageName = 'Ensure-Fast-Startup-Disabled'
$ScriptName = 'Remediate'

$PowerRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
$HiberbootValueName = 'HiberbootEnabled'
$TargetHiberbootValue = 0
$ApplyRegistryChange = $false

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
    Write-Log -Message "Remediation started. ApplyRegistryChange='$ApplyRegistryChange'."

    if (-not $ApplyRegistryChange) {
        Write-Output "Report-only mode. Would set '$PowerRegistryPath\$HiberbootValueName' to '$TargetHiberbootValue'."
        exit 0
    }

    if (-not (Test-Path -LiteralPath $PowerRegistryPath)) {
        New-Item -Path $PowerRegistryPath -Force | Out-Null
    }

    New-ItemProperty -LiteralPath $PowerRegistryPath -Name $HiberbootValueName -PropertyType DWord -Value $TargetHiberbootValue -Force | Out-Null
    Write-Output 'Remediation completed. Fast Startup registry value was updated.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Fast Startup was not changed.'
    exit 1
}
