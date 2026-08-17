<#
.SYNOPSIS
    Exports OneDrive sync client state signals.

.DESCRIPTION
    Intune platform script for Microsoft 365 Business Premium environments.
    The script collects OneDrive executable version and profile sync folder
    signals for Known Folder Move and sync troubleshooting.

.NOTES
    Name:        Export-OneDrive-Sync-Client-State.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Platform Script
    Exit 0:      OneDrive state exported
    Exit 1:      OneDrive state export failed

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

$ScriptPackageName = 'Export-OneDrive-Sync-Client-State'
$ScriptName = 'Export-OneDrive-Sync-Client-State'

$OutputRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$OutputFileName = 'OneDriveSyncClientState.json'
$OneDriveExecutableCandidates = @(
    (Join-Path -Path $env:ProgramFiles -ChildPath 'Microsoft OneDrive\OneDrive.exe'),
    (Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'Microsoft OneDrive\OneDrive.exe')
)
$UserProfileRoot = 'C:\Users'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }; if (-not (Test-Path -LiteralPath $OutputRoot)) { New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $oneDriveExecutable = $OneDriveExecutableCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    $oneDriveVersion = if ($oneDriveExecutable) { (Get-Item -LiteralPath $oneDriveExecutable).VersionInfo.ProductVersion } else { '' }
    $profileSignals = @()

    if (Test-Path -LiteralPath $UserProfileRoot -PathType Container) {
        $profileSignals = @(Get-ChildItem -LiteralPath $UserProfileRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $oneDriveFolders = @(Get-ChildItem -LiteralPath $_.FullName -Directory -Filter 'OneDrive*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
            [pscustomobject]@{
                ProfileName = $_.Name
                ProfilePath = $_.FullName
                OneDriveFolderCount = $oneDriveFolders.Count
                OneDriveFolders = $oneDriveFolders
            }
        })
    }

    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        CapturedAt = (Get-Date).ToString('o')
        OneDriveExecutable = [string]$oneDriveExecutable
        OneDriveVersion = $oneDriveVersion
        ProfileSignals = $profileSignals
    }

    $outputPath = Join-Path -Path $OutputRoot -ChildPath $OutputFileName
    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $outputPath -Encoding UTF8
    Write-Log -Message "OneDrive sync client state exported to '$outputPath'."
    Write-Output "OneDrive sync client state exported to '$outputPath'."
    exit 0
}
catch {
    try { Write-Log -Message "OneDrive sync client state export failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'OneDrive sync client state export failed.'
    exit 1
}
