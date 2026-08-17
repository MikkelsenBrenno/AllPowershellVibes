<#
.SYNOPSIS
    Uninstalls a local MSI package by product code.

.DESCRIPTION
    Win32 app uninstall script template. The script uninstalls an MSI by
    product code and treats product-not-installed as success.

.NOTES
    Name:        Uninstall.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      MSI uninstall succeeded
    Exit 1:      MSI uninstall failed
    Exit 3010:   MSI uninstall succeeded and restart is required

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
$ScriptName = 'Uninstall'

$ProductCode = '{00000000-0000-0000-0000-000000000000}'
$AdditionalMsiArguments = '/qn /norestart'
$MsiLogFileName = 'Uninstall-MSI.log'
$AcceptedSuccessExitCodes = @(0, 1605, 3010)

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

try {
    Initialize-Log
    Write-ScriptMetadata

    if ($ProductCode -eq '{00000000-0000-0000-0000-000000000000}') {
        throw 'Replace ProductCode placeholder before deployment.'
    }

    $msiLogPath = Join-Path -Path $LogRoot -ChildPath $MsiLogFileName
    $argumentList = @('/x', $ProductCode, $AdditionalMsiArguments, '/L*v', "`"$msiLogPath`"") -join ' '
    $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList $argumentList -Wait -PassThru -WindowStyle Hidden

    Write-Log -Message "msiexec uninstall exit code '$($process.ExitCode)'."

    if ($AcceptedSuccessExitCodes -notcontains [int]$process.ExitCode) {
        throw "MSI uninstall failed with exit code '$($process.ExitCode)'."
    }

    Write-Output "Uninstall completed for MSI product '$ProductCode'."
    exit $process.ExitCode
}
catch {
    try { Write-Log -Message "Uninstall failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Uninstall failed.'
    exit 1
}
