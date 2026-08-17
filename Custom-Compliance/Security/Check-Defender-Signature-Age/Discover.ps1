<#
.SYNOPSIS
    Discovers Microsoft Defender Antivirus signature age.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks Defender
    signature last updated time and reports whether it is fresh enough.

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

$ScriptPackageName = 'Check-Defender-Signature-Age'
$ScriptName = 'Discover'

$MaximumSignatureAgeDays = 3

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
    DefenderSignatureFresh = $false
    DefenderSignatureAgeDays = 999
    DefenderSignatureLastUpdated = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata
    if (-not (Get-Command -Name Get-MpComputerStatus -ErrorAction SilentlyContinue)) { throw 'Get-MpComputerStatus is not available.' }
    $status = Get-MpComputerStatus -ErrorAction Stop
    $lastUpdated = [datetime]$status.AntivirusSignatureLastUpdated
    $ageDays = [int][math]::Floor(((Get-Date) - $lastUpdated).TotalDays)
    $result.DefenderSignatureLastUpdated = $lastUpdated.ToString('s')
    $result.DefenderSignatureAgeDays = $ageDays
    $result.DefenderSignatureFresh = ($ageDays -le $MaximumSignatureAgeDays)
    Write-Log -Message "Discovery completed. LastUpdated='$lastUpdated'; AgeDays='$ageDays'; Fresh='$($result.DefenderSignatureFresh)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
