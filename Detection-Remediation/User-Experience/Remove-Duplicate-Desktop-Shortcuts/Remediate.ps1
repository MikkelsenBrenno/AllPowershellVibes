<#
.SYNOPSIS
    Removes duplicate desktop shortcut files.

.DESCRIPTION
    Intune Remediations remediation script. The script keeps one shortcut per
    file name and can remove duplicates from the configured desktop roots. It
    is report-only by default.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     User recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation completed or report-only mode completed
    Exit 1:      Remediation failed

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

$ScriptPackageName = 'Remove-Duplicate-Desktop-Shortcuts'
$ScriptName = 'Remediate'

$DesktopRoots = @(
    (Join-Path -Path $env:PUBLIC -ChildPath 'Desktop'),
    ([Environment]::GetFolderPath('Desktop'))
)
$ShortcutExtensions = @('.lnk', '.url')
$ApplyShortcutRemoval = $false
$KeepNewestShortcut = $true

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-DesktopShortcut {
    foreach ($root in $DesktopRoots | Select-Object -Unique) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -File -ErrorAction SilentlyContinue | Where-Object {
            $ShortcutExtensions -contains $_.Extension
        } | ForEach-Object {
            [pscustomobject]@{
                Name = $_.Name
                FullName = $_.FullName
                LastWriteTime = $_.LastWriteTime
            }
        }
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $duplicateGroups = @(Get-DesktopShortcut | Group-Object Name | Where-Object { $_.Count -gt 1 })
    $removeTargets = @()

    foreach ($group in $duplicateGroups) {
        if ($KeepNewestShortcut) {
            $ordered = @($group.Group | Sort-Object LastWriteTime -Descending)
        }
        else {
            $ordered = @($group.Group | Sort-Object FullName)
        }

        $removeTargets += @($ordered | Select-Object -Skip 1)
    }

    if (-not $ApplyShortcutRemoval) {
        Write-Output "Report-only mode. Would remove duplicate shortcuts: $(@($removeTargets | Select-Object -ExpandProperty FullName) -join ', ')."
        exit 0
    }

    foreach ($target in $removeTargets) {
        Write-Log -Message "Removing duplicate shortcut '$($target.FullName)'."
        Remove-Item -LiteralPath $target.FullName -Force -ErrorAction Stop
    }

    Write-Output "Remediation completed. Removed '$($removeTargets.Count)' duplicate shortcuts."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Duplicate shortcuts were not removed.'
    exit 1
}
