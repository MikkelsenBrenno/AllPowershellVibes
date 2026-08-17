<#
.SYNOPSIS
    Discovers AutoRun and AutoPlay policy state for custom compliance.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks configurable
    Explorer policy registry values and returns one compressed JSON object.

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

$ScriptPackageName = 'Check-AutoRun-AutoPlay-Policy'
$ScriptName = 'Discover'

$ExplorerPolicyPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
$NoDriveTypeAutoRunValueName = 'NoDriveTypeAutoRun'
$ExpectedNoDriveTypeAutoRunValue = 255
$NoAutorunValueName = 'NoAutorun'
$ExpectedNoAutorunValue = 1
$RequireNoAutorunValue = $true

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
    AutoRunAutoPlayCompliant = $false
    RegistryPathExists = $false
    NoDriveTypeAutoRunValue = -1
    ExpectedNoDriveTypeAutoRunValue = [int]$ExpectedNoDriveTypeAutoRunValue
    NoAutorunValue = -1
    ExpectedNoAutorunValue = [int]$ExpectedNoAutorunValue
    RequireNoAutorunValue = [bool]$RequireNoAutorunValue
}

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Test-Path -LiteralPath $ExplorerPolicyPath -PathType Container)) {
        throw "Registry path '$ExplorerPolicyPath' was not found."
    }

    $item = Get-ItemProperty -LiteralPath $ExplorerPolicyPath -ErrorAction Stop
    $actualNoDriveTypeAutoRunValue = [int]$item.$NoDriveTypeAutoRunValueName
    $actualNoAutorunValue = -1

    if ($RequireNoAutorunValue) {
        $actualNoAutorunValue = [int]$item.$NoAutorunValueName
    }

    $result.RegistryPathExists = $true
    $result.NoDriveTypeAutoRunValue = $actualNoDriveTypeAutoRunValue
    $result.NoAutorunValue = $actualNoAutorunValue
    $result.AutoRunAutoPlayCompliant = (
        $actualNoDriveTypeAutoRunValue -eq $ExpectedNoDriveTypeAutoRunValue -and
        (-not $RequireNoAutorunValue -or $actualNoAutorunValue -eq $ExpectedNoAutorunValue)
    )

    Write-Log -Message "Discovery completed. NoDriveTypeAutoRun='$actualNoDriveTypeAutoRunValue'; NoAutorun='$actualNoAutorunValue'; Compliant='$($result.AutoRunAutoPlayCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.AutoRunAutoPlayCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
