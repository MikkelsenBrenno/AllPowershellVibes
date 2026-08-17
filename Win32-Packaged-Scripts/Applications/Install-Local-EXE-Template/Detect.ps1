<#
.SYNOPSIS
    Detects a local EXE-installed application.

.DESCRIPTION
    Win32 app custom detection script template. Intune considers the app
    detected only when this script exits 0 and writes a string to STDOUT.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Detection
    Exit 0:      Application detected, with STDOUT
    Exit 1:      Application missing

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

$ScriptPackageName = 'Install-Local-EXE-Template'
$ScriptName = 'Detect'

$ExpectedDisplayNamePattern = 'Example Application'
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
    param([string]$ActualVersion, [string]$MinimumVersion)
    if ([string]::IsNullOrWhiteSpace($MinimumVersion)) { return $true }
    try { return ([version]$ActualVersion -ge [version]$MinimumVersion) } catch { return $false }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    foreach ($path in $UninstallRegistryPaths) {
        if (Test-Path -LiteralPath $path) {
            $apps = Get-ChildItem -LiteralPath $path -ErrorAction SilentlyContinue | ForEach-Object {
                Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            }

            foreach ($app in $apps) {
                if (-not [string]::IsNullOrWhiteSpace($app.DisplayName) -and $app.DisplayName -like "*$ExpectedDisplayNamePattern*" -and (Test-VersionMeetsMinimum -ActualVersion $app.DisplayVersion -MinimumVersion $MinimumDisplayVersion)) {
                    Write-Output "Detected. Application '$($app.DisplayName)' version '$($app.DisplayVersion)' is installed."
                    exit 0
                }
            }
        }
    }

    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    exit 1
}
