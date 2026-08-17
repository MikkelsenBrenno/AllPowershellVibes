<#
.SYNOPSIS
    Detects whether Windows Fast Startup is disabled.

.DESCRIPTION
    Intune Remediations detection script. The script checks the HiberbootEnabled
    registry value used by Windows Fast Startup.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Fast Startup is disabled
    Exit 1:      Fast Startup is enabled or could not be validated

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
$ScriptName = 'Detect'

$PowerRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
$HiberbootValueName = 'HiberbootEnabled'
$ExpectedHiberbootValue = 0

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

    $properties = Get-ItemProperty -LiteralPath $PowerRegistryPath -Name $HiberbootValueName -ErrorAction SilentlyContinue
    $currentValue = 0

    if ($null -ne $properties -and $null -ne $properties.$HiberbootValueName) {
        $currentValue = [int]$properties.$HiberbootValueName
    }

    if ($currentValue -eq $ExpectedHiberbootValue) {
        $message = "Compliant. Fast Startup value '$HiberbootValueName' is '$currentValue'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Fast Startup value '$HiberbootValueName' is '$currentValue'; Expected='$ExpectedHiberbootValue'."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Fast Startup could not be validated.'
    exit 1
}
