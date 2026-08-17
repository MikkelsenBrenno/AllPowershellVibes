<#
.SYNOPSIS
    Uninstalls a local support tool bundle.

.DESCRIPTION
    Win32 app uninstall script template. The script removes the installed
    support tool bundle folder or only the detection marker, depending on the
    configured safety option.

.NOTES
    Name:        Uninstall.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Support tool bundle removed or marker removed
    Exit 1:      Support tool bundle uninstall failed

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

$ScriptPackageName = 'Install-Local-Support-Tool-Bundle'
$ScriptName = 'Uninstall'

$DestinationRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\SupportTools\ExampleBundle'
$DetectionMarkerFileName = 'install-marker.json'
$RemoveDestinationRoot = $true

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

    if ($RemoveDestinationRoot) {
        if (Test-Path -LiteralPath $DestinationRoot -PathType Container) {
            Remove-Item -LiteralPath $DestinationRoot -Recurse -Force
            Write-Log -Message "Removed destination folder '$DestinationRoot'."
        }
    }
    else {
        $markerPath = Join-Path -Path $DestinationRoot -ChildPath $DetectionMarkerFileName
        if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
            Remove-Item -LiteralPath $markerPath -Force
            Write-Log -Message "Removed detection marker '$markerPath'."
        }
    }

    Write-Output 'Uninstall succeeded. Support tool bundle marker is absent.'
    exit 0
}
catch {
    try { Write-Log -Message "Uninstall failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Uninstall failed.'
    exit 1
}
