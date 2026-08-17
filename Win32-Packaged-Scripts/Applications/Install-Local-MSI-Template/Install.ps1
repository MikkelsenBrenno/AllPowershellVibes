<#
.SYNOPSIS
    Installs a local MSI package.

.DESCRIPTION
    Win32 app install script template. The script installs an MSI included in
    the package folder and validates detection by MSI product code.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      MSI install succeeded
    Exit 1:      MSI install failed
    Exit 3010:   MSI install succeeded and restart is required

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

$ScriptPackageName = 'Install-Local-MSI-Template'
$ScriptName = 'Install'

$MsiFileName = 'ExampleInstaller.msi'
$ProductCode = '{00000000-0000-0000-0000-000000000000}'
$AdditionalMsiArguments = '/qn /norestart'
$MsiLogFileName = 'Install-MSI.log'
$AcceptedSuccessExitCodes = @(0, 3010)

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Test-MsiProductInstalled {
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$ProductCode",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$ProductCode"
    )

    foreach ($path in $uninstallPaths) {
        if (Test-Path -LiteralPath $path -PathType Container) {
            return $true
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

    if ($MsiFileName -eq 'ExampleInstaller.msi' -or $ProductCode -eq '{00000000-0000-0000-0000-000000000000}') {
        throw 'Replace MsiFileName and ProductCode placeholders before deployment.'
    }

    $msiPath = Join-Path -Path $PSScriptRoot -ChildPath $MsiFileName
    if (-not (Test-Path -LiteralPath $msiPath -PathType Leaf)) {
        throw "MSI file '$msiPath' was not found."
    }

    $msiLogPath = Join-Path -Path $LogRoot -ChildPath $MsiLogFileName
    $argumentList = @('/i', "`"$msiPath`"", $AdditionalMsiArguments, '/L*v', "`"$msiLogPath`"") -join ' '
    $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $argumentList -Wait -PassThru -WindowStyle Hidden

    Write-Log -Message "msiexec install exit code '$($process.ExitCode)'."

    if ($AcceptedSuccessExitCodes -notcontains [int]$process.ExitCode) {
        throw "MSI install failed with exit code '$($process.ExitCode)'."
    }

    if (-not (Test-MsiProductInstalled)) {
        throw "Product code '$ProductCode' was not detected after install."
    }

    Write-Output "Install succeeded. MSI product '$ProductCode' is installed."
    exit $process.ExitCode
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
