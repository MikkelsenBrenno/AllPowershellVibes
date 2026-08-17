<#
.SYNOPSIS
    Discovers battery charge state.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks battery
    charge percentages and returns one compressed JSON object.

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

$ScriptPackageName = 'Check-Battery-Charge-State'
$ScriptName = 'Discover'

$MinimumChargePercent = 20
$TreatNoBatteryAsCompliant = $true

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
    BatteryChargeCompliant = $false
    BatteryCount = 0
    LowestBatteryChargePercent = -1
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $batteries = @(Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue)
    $result.BatteryCount = $batteries.Count

    if ($batteries.Count -eq 0) {
        $result.BatteryChargeCompliant = [bool]$TreatNoBatteryAsCompliant
        $result.LowestBatteryChargePercent = -1
    }
    else {
        $lowestCharge = ($batteries | Measure-Object -Property EstimatedChargeRemaining -Minimum).Minimum
        $result.LowestBatteryChargePercent = [int]$lowestCharge
        $result.BatteryChargeCompliant = ([int]$lowestCharge -ge $MinimumChargePercent)
    }

    Write-Log -Message "Discovery completed. BatteryCount='$($result.BatteryCount)'; LowestCharge='$($result.LowestBatteryChargePercent)'; MinimumChargePercent='$MinimumChargePercent'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.BatteryChargeCompliant = $false
    $result.LowestBatteryChargePercent = -1
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
