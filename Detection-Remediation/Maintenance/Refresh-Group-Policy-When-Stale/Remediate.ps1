<#
.SYNOPSIS
    Runs gpupdate when Group Policy refresh is stale.

.DESCRIPTION
    Intune Remediations remediation script. The script runs configurable
    gpupdate targets and logs the exit code for each target.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      gpupdate completed
    Exit 1:      gpupdate failed

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

$ScriptPackageName = 'Refresh-Group-Policy-When-Stale'
$ScriptName = 'Remediate'

$GpUpdatePath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\gpupdate.exe'
$TargetsToRefresh = @('computer')
$ForceRefresh = $true
$WaitForCompletion = $true

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Invoke-GpUpdateTarget {
    param([Parameter(Mandatory = $true)][string]$Target)

    $arguments = @("/target:$Target")
    if ($ForceRefresh) { $arguments += '/force' }
    if ($WaitForCompletion) { $arguments += '/wait:0' }

    Write-Log -Message "Running gpupdate. FilePath='$GpUpdatePath'; Arguments='$($arguments -join ' ')'."
    & $GpUpdatePath @arguments
    $exitCode = $LASTEXITCODE
    Write-Log -Message "gpupdate target '$Target' completed with exit code '$exitCode'."

    if ($exitCode -ne 0) {
        throw "gpupdate failed for target '$Target' with exit code '$exitCode'."
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Test-Path -LiteralPath $GpUpdatePath -PathType Leaf)) {
        throw "gpupdate.exe was not found at '$GpUpdatePath'."
    }

    foreach ($target in $TargetsToRefresh) {
        Invoke-GpUpdateTarget -Target $target
    }

    Write-Output "Remediation completed. gpupdate ran for targets: $($TargetsToRefresh -join ', ')."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Group Policy refresh did not complete.'
    exit 1
}
