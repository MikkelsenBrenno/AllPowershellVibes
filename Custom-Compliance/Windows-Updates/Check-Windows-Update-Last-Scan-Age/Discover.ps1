<#
.SYNOPSIS
    Discovers Windows Update last scan age.

.DESCRIPTION
    Intune custom compliance discovery script. The script reads the Windows
    Update automatic update COM object and returns one compressed JSON object
    indicating whether the last scan is recent enough.

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

$ScriptPackageName = 'Check-Windows-Update-Last-Scan-Age'
$ScriptName = 'Discover'

$MaximumLastScanAgeDays = 7
$TreatNeverScannedAsCompliant = $false

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
    WindowsUpdateLastScanWithinLimit = $false
    LastSearchSuccessDate = ''
    LastScanAgeDays = -1
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $autoUpdate = New-Object -ComObject 'Microsoft.Update.AutoUpdate'
    $lastSearch = $autoUpdate.Results.LastSearchSuccessDate

    if ($null -eq $lastSearch -or $lastSearch.Year -lt 2000) {
        $result.WindowsUpdateLastScanWithinLimit = [bool]$TreatNeverScannedAsCompliant
        $result.LastSearchSuccessDate = 'Never'
    }
    else {
        $age = New-TimeSpan -Start $lastSearch -End (Get-Date)
        $result.LastSearchSuccessDate = $lastSearch.ToString('yyyy-MM-dd HH:mm:ss')
        $result.LastScanAgeDays = [math]::Round($age.TotalDays, 2)
        $result.WindowsUpdateLastScanWithinLimit = ($age.TotalDays -le $MaximumLastScanAgeDays)
    }

    Write-Log -Message "Discovery completed. LastSearch='$($result.LastSearchSuccessDate)'; AgeDays='$($result.LastScanAgeDays)'; MaximumDays='$MaximumLastScanAgeDays'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.WindowsUpdateLastScanWithinLimit = $false
    $result.LastSearchSuccessDate = 'Error'
    $result.LastScanAgeDays = -1
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
