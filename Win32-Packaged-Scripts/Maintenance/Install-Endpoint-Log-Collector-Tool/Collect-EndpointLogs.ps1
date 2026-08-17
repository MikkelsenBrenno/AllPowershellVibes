<#
.SYNOPSIS
    Collects common endpoint troubleshooting logs into a zip file.

.DESCRIPTION
    Helper script installed by the Win32 package. The script copies selected
    log folders into a timestamped staging folder and compresses them for
    technician handoff.

.NOTES
    Name:        Collect-EndpointLogs.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System or administrator

.INTUNE
    Workload:    Win32 App Payload
    Exit 0:      Log bundle created
    Exit 1:      Log bundle creation failed

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

$ScriptPackageName = 'Install-Endpoint-Log-Collector-Tool'
$ScriptName = 'Collect-EndpointLogs'

$BundleRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\CollectedLogs'
$SourceLogFolders = @(
    (Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneManagementExtension\Logs'),
    (Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs')
)
$MaxFilesPerSource = 50

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }; if (-not (Test-Path -LiteralPath $BundleRoot)) { New-Item -Path $BundleRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $stagingRoot = Join-Path -Path $BundleRoot -ChildPath "EndpointLogs-$env:COMPUTERNAME-$timestamp"
    $zipPath = "$stagingRoot.zip"
    New-Item -Path $stagingRoot -ItemType Directory -Force | Out-Null

    foreach ($source in $SourceLogFolders) {
        if (-not (Test-Path -LiteralPath $source -PathType Container)) {
            Write-Log -Message "Skipping missing source '$source'." -Level 'WARN'
            continue
        }

        $safeName = ($source -replace '[:\\\/]', '_').Trim('_')
        $destination = Join-Path -Path $stagingRoot -ChildPath $safeName
        New-Item -Path $destination -ItemType Directory -Force | Out-Null

        Get-ChildItem -LiteralPath $source -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First $MaxFilesPerSource |
            Copy-Item -Destination $destination -Force
    }

    Compress-Archive -Path (Join-Path -Path $stagingRoot -ChildPath '*') -DestinationPath $zipPath -Force
    Write-Log -Message "Log bundle created. Path='$zipPath'."
    Write-Output "Log bundle created at '$zipPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Log collection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Log collection failed.'
    exit 1
}
