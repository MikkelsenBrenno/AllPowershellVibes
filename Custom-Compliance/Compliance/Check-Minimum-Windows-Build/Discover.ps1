<#
.SYNOPSIS
    Discovers whether Windows meets a minimum build.

.DESCRIPTION
    Intune custom compliance discovery script. The script reads operating
    system build information and returns one compressed JSON object.

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

$ScriptPackageName = 'Check-Minimum-Windows-Build'
$ScriptName = 'Discover'

$MinimumBuildNumber = 22631
$CurrentVersionRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'

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
    WindowsBuildCompliant = $false
    CurrentBuildNumber = 0
    CurrentUBR = 0
    WindowsProductName = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $versionInfo = Get-ItemProperty -LiteralPath $CurrentVersionRegistryPath -ErrorAction SilentlyContinue
    $buildNumber = [int]$os.BuildNumber
    $ubr = 0

    if ($null -ne $versionInfo -and $null -ne $versionInfo.UBR) {
        $ubr = [int]$versionInfo.UBR
    }

    $result.CurrentBuildNumber = $buildNumber
    $result.CurrentUBR = $ubr
    $result.WindowsProductName = [string]$os.Caption
    $result.WindowsBuildCompliant = ($buildNumber -ge $MinimumBuildNumber)

    Write-Log -Message "Discovery completed. Build='$buildNumber'; UBR='$ubr'; MinimumBuildNumber='$MinimumBuildNumber'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.WindowsBuildCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
