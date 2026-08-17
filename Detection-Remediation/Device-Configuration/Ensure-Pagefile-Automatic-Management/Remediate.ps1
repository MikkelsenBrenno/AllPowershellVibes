<#
.SYNOPSIS
    Configures automatic pagefile management.

.DESCRIPTION
    Intune Remediations remediation script. The script can set
    Win32_ComputerSystem.AutomaticManagedPagefile to the configured value. It
    runs in report-only mode by default so teams can pilot first.

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

$ScriptPackageName = 'Ensure-Pagefile-Automatic-Management'
$ScriptName = 'Remediate'

$ExpectedAutomaticManagedPagefile = $true
$ApplyPagefileChange = $false
$RebootMessage = 'A reboot may be required before pagefile changes are fully applied.'

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
    Write-Log -Message "Remediation started. ExpectedAutomaticManagedPagefile='$ExpectedAutomaticManagedPagefile'; ApplyPagefileChange='$ApplyPagefileChange'."

    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
    $current = [bool]$computerSystem.AutomaticManagedPagefile

    if ($current -eq [bool]$ExpectedAutomaticManagedPagefile) {
        Write-Output "No change needed. AutomaticManagedPagefile='$current'."
        exit 0
    }

    if (-not $ApplyPagefileChange) {
        Write-Output "Report-only mode. Would set AutomaticManagedPagefile to '$ExpectedAutomaticManagedPagefile'."
        exit 0
    }

    Set-CimInstance -InputObject $computerSystem -Property @{ AutomaticManagedPagefile = [bool]$ExpectedAutomaticManagedPagefile } -ErrorAction Stop | Out-Null
    Write-Log -Message $RebootMessage -Level 'WARN'
    Write-Output "Remediation completed. $RebootMessage"
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Automatic pagefile management was not changed.'
    exit 1
}
