<#
.SYNOPSIS
    Installs a local EXE package.

.DESCRIPTION
    Win32 app install script template. The script runs a configurable EXE
    installer included in the package folder and validates detection by
    application display name in uninstall registry entries.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      EXE install succeeded
    Exit 1:      EXE install failed
    Exit 3010:   EXE install succeeded and restart is required

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
$ScriptName = 'Install'

$InstallerFileName = 'ExampleSetup.exe'
$InstallerArguments = '/quiet /norestart'
$ExpectedDisplayNamePattern = 'Example Application'
$MinimumDisplayVersion = ''
$AcceptedSuccessExitCodes = @(0, 3010)
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

function Test-ApplicationDetected {
    foreach ($path in $UninstallRegistryPaths) {
        if (Test-Path -LiteralPath $path) {
            $apps = Get-ChildItem -LiteralPath $path -ErrorAction SilentlyContinue | ForEach-Object {
                Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            }

            foreach ($app in $apps) {
                if (-not [string]::IsNullOrWhiteSpace($app.DisplayName) -and $app.DisplayName -like "*$ExpectedDisplayNamePattern*") {
                    if ([string]::IsNullOrWhiteSpace($MinimumDisplayVersion)) {
                        return $true
                    }

                    try {
                        if ([version]$app.DisplayVersion -ge [version]$MinimumDisplayVersion) {
                            return $true
                        }
                    }
                    catch {
                    }
                }
            }
        }
    }

    return $false
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if ($InstallerFileName -eq 'ExampleSetup.exe' -or $ExpectedDisplayNamePattern -eq 'Example Application') {
        throw 'Replace InstallerFileName and ExpectedDisplayNamePattern placeholders before deployment.'
    }

    $installerPath = Join-Path -Path $PSScriptRoot -ChildPath $InstallerFileName
    if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
        throw "Installer file '$installerPath' was not found."
    }

    $process = Start-Process -FilePath $installerPath -ArgumentList $InstallerArguments -Wait -PassThru -WindowStyle Hidden
    Write-Log -Message "Installer exit code '$($process.ExitCode)'."

    if ($AcceptedSuccessExitCodes -notcontains [int]$process.ExitCode) {
        throw "Installer failed with exit code '$($process.ExitCode)'."
    }

    if (-not (Test-ApplicationDetected)) {
        throw "Application matching '$ExpectedDisplayNamePattern' was not detected after install."
    }

    Write-Output "Install succeeded. Application matching '$ExpectedDisplayNamePattern' is installed."
    exit $process.ExitCode
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
