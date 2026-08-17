<#
.SYNOPSIS
    Detects duplicate desktop shortcut files.

.DESCRIPTION
    Intune Remediations detection script. The script scans configurable desktop
    roots and reports noncompliance when the same shortcut file name appears in
    more than one location.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     User recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Duplicate desktop shortcuts were not found
    Exit 1:      Duplicate desktop shortcuts were found

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
$ScriptName = 'Detect'

$DesktopRoots = @(
    (Join-Path -Path $env:PUBLIC -ChildPath 'Desktop'),
    ([Environment]::GetFolderPath('Desktop'))
)
$ShortcutExtensions = @('.lnk', '.url')

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
                Directory = $root
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

    $duplicates = @(Get-DesktopShortcut | Group-Object Name | Where-Object { $_.Count -gt 1 })

    if ($duplicates.Count -eq 0) {
        $message = 'Compliant. Duplicate desktop shortcuts were not found.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $duplicateNames = @($duplicates | Select-Object -ExpandProperty Name)
    $message = "Not compliant. Duplicate desktop shortcuts found: $($duplicateNames -join ', ')."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Duplicate desktop shortcuts could not be validated.'
    exit 1
}
