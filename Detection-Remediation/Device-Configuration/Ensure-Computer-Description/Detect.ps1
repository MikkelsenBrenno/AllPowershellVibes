<#
.SYNOPSIS
    Detects the local computer description.

.DESCRIPTION
    Intune Remediations detection script. The script checks the LanmanServer
    computer description registry value against a configurable expected value.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Computer description is compliant
    Exit 1:      Computer description is missing or different

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

$ScriptPackageName = 'Ensure-Computer-Description'
$ScriptName = 'Detect'

$LanmanServerParametersPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
$DescriptionValueName = 'srvcomment'
$ExpectedDescription = 'Managed by Contoso IT'

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
    $item = Get-ItemProperty -LiteralPath $LanmanServerParametersPath -Name $DescriptionValueName -ErrorAction SilentlyContinue
    $actualDescription = if ($null -ne $item) { [string]$item.$DescriptionValueName } else { '' }

    if ($actualDescription -eq $ExpectedDescription) {
        Write-Output "Compliant. Computer description is '$actualDescription'."
        exit 0
    }

    Write-Output "Not compliant. Computer description is '$actualDescription'."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Computer description could not be validated.'
    exit 1
}
