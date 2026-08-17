<#
.SYNOPSIS
    Uninstalls a local EXE-installed application.

.DESCRIPTION
    Win32 app uninstall script template. The script runs a configurable
    uninstall command and validates that the expected display name is absent.

.NOTES
    Name:        Uninstall.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Application uninstall succeeded
    Exit 1:      Application uninstall failed

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
$ScriptName = 'Uninstall'

$UninstallerFilePath = 'C:\Program Files\Example Application\Uninstall.exe'
$UninstallerArguments = '/quiet /norestart'
$ExpectedDisplayNamePattern = 'Example Application'
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
                    return $true
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

    if ($UninstallerFilePath -eq 'C:\Program Files\Example Application\Uninstall.exe' -or $ExpectedDisplayNamePattern -eq 'Example Application') {
        throw 'Replace UninstallerFilePath and ExpectedDisplayNamePattern placeholders before deployment.'
    }

    if (Test-Path -LiteralPath $UninstallerFilePath -PathType Leaf) {
        $process = Start-Process -FilePath $UninstallerFilePath -ArgumentList $UninstallerArguments -Wait -PassThru -WindowStyle Hidden
        Write-Log -Message "Uninstaller exit code '$($process.ExitCode)'."

        if ($AcceptedSuccessExitCodes -notcontains [int]$process.ExitCode) {
            throw "Uninstaller failed with exit code '$($process.ExitCode)'."
        }
    }

    if (Test-ApplicationDetected) {
        throw "Application matching '$ExpectedDisplayNamePattern' is still detected after uninstall."
    }

    Write-Output "Uninstall succeeded. Application matching '$ExpectedDisplayNamePattern' is absent."
    exit 0
}
catch {
    try { Write-Log -Message "Uninstall failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Uninstall failed.'
    exit 1
}
