<#
.SYNOPSIS
    Discovers Microsoft Defender tamper protection state.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks Microsoft
    Defender status and returns one compressed JSON object with tamper
    protection state when available.

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

$ScriptPackageName = 'Check-Defender-Tamper-Protection-State'
$ScriptName = 'Discover'

$ExpectedTamperProtectedState = $true
$TreatMissingPropertyAsNonCompliant = $true

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
    DefenderTamperProtectionCompliant = $false
    DefenderStatusAvailable = $false
    TamperProtectionPropertyAvailable = $false
    IsTamperProtected = $false
    ExpectedTamperProtectedState = [bool]$ExpectedTamperProtectedState
}

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Get-Command -Name Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
        throw 'Get-MpComputerStatus is not available.'
    }

    $status = Get-MpComputerStatus -ErrorAction Stop
    $result.DefenderStatusAvailable = $true
    $tamperProperty = $status.PSObject.Properties['IsTamperProtected']

    if ($null -ne $tamperProperty) {
        $result.TamperProtectionPropertyAvailable = $true
        $result.IsTamperProtected = [bool]$tamperProperty.Value
        $result.DefenderTamperProtectionCompliant = ($result.IsTamperProtected -eq $ExpectedTamperProtectedState)
    }
    elseif (-not $TreatMissingPropertyAsNonCompliant) {
        $result.DefenderTamperProtectionCompliant = $true
    }

    Write-Log -Message "Discovery completed. PropertyAvailable='$($result.TamperProtectionPropertyAvailable)'; IsTamperProtected='$($result.IsTamperProtected)'; Expected='$ExpectedTamperProtectedState'; Compliant='$($result.DefenderTamperProtectionCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.DefenderTamperProtectionCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
