<#
.SYNOPSIS
    Discovers whether a required application is installed.

.DESCRIPTION
    Intune custom compliance discovery script. The script searches common
    machine-wide uninstall registry locations for a configurable application
    display name pattern and returns one compressed JSON object.

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

$ScriptPackageName = 'Check-Required-App-Installed'
$ScriptName = 'Discover'

$ApplicationDisplayNamePattern = 'Company Portal'
$MinimumDisplayVersion = ''
$UninstallRegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Test-VersionMeetsMinimum {
    param(
        [string]$ActualVersion,
        [string]$MinimumVersion
    )

    if ([string]::IsNullOrWhiteSpace($MinimumVersion)) {
        return $true
    }

    try {
        return ([version]$ActualVersion -ge [version]$MinimumVersion)
    }
    catch {
        return $false
    }
}

# =========================
# MAIN
# =========================

$result = [ordered]@{
    RequiredAppInstalled = $false
    ApplicationDisplayNamePattern = $ApplicationDisplayNamePattern
    MinimumDisplayVersion = $MinimumDisplayVersion
    MatchedDisplayName = ''
    MatchedDisplayVersion = ''
    MatchCount = 0
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $matches = foreach ($path in $UninstallRegistryPaths) {
        if (Test-Path -LiteralPath $path) {
            Get-ChildItem -LiteralPath $path -ErrorAction SilentlyContinue | ForEach-Object {
                $app = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
                if (-not [string]::IsNullOrWhiteSpace($app.DisplayName) -and $app.DisplayName -like "*$ApplicationDisplayNamePattern*") {
                    [pscustomobject]@{
                        DisplayName = [string]$app.DisplayName
                        DisplayVersion = [string]$app.DisplayVersion
                        Publisher = [string]$app.Publisher
                    }
                }
            }
        }
    }

    $matches = @($matches)
    $result.MatchCount = $matches.Count

    foreach ($match in $matches) {
        if (Test-VersionMeetsMinimum -ActualVersion $match.DisplayVersion -MinimumVersion $MinimumDisplayVersion) {
            $result.RequiredAppInstalled = $true
            $result.MatchedDisplayName = [string]$match.DisplayName
            $result.MatchedDisplayVersion = [string]$match.DisplayVersion
            break
        }
    }

    Write-Log -Message "Discovery completed. Pattern='$ApplicationDisplayNamePattern'; MatchCount='$($result.MatchCount)'; Installed='$($result.RequiredAppInstalled)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.RequiredAppInstalled = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
