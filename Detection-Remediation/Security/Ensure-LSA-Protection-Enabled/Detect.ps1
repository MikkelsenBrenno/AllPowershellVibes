<#
.SYNOPSIS
    Detects whether Local Security Authority protection is enabled.

.DESCRIPTION
    Intune Remediations detection script. The script checks the RunAsPPL
    registry value under the LSA configuration path.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      LSA protection is enabled
    Exit 1:      LSA protection is missing or below the expected value

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

$ScriptPackageName = 'Ensure-LSA-Protection-Enabled'
$ScriptName = 'Detect'

$LsaRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
$RunAsPplValueName = 'RunAsPPL'
$MinimumCompliantValue = 1

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

    $properties = Get-ItemProperty -LiteralPath $LsaRegistryPath -Name $RunAsPplValueName -ErrorAction SilentlyContinue
    $currentValue = 0

    if ($null -ne $properties -and $null -ne $properties.$RunAsPplValueName) {
        $currentValue = [int]$properties.$RunAsPplValueName
    }

    if ($currentValue -ge $MinimumCompliantValue) {
        $message = "Compliant. LSA protection value '$RunAsPplValueName' is '$currentValue'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. LSA protection value '$RunAsPplValueName' is '$currentValue'; Minimum='$MinimumCompliantValue'."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'LSA protection could not be validated.'
    exit 1
}
