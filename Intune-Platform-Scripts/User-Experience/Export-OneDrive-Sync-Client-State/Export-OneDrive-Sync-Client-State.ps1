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
    Workload:    Intune Platform Scripts
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

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }; if (-not (Test-Path -LiteralPath $OutputRoot)) { New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-TargetUserProfilePath {
    try {
        $profiles = @(Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop |
            Where-Object { -not $_.Special -and -not [string]::IsNullOrWhiteSpace($_.LocalPath) -and (Test-Path -LiteralPath $_.LocalPath -PathType Container) } |
            Select-Object -ExpandProperty LocalPath -Unique)

        if ($profiles.Count -gt 0) {
            return $profiles
        }
    }
    catch {
        Write-Log -Message "Could not query Win32_UserProfile. Falling back to SystemDrive user profile root. $($_.Exception.Message)" -Level 'WARN'
    }

    $fallbackProfileRoot = Join-Path -Path $env:SystemDrive -ChildPath 'Users'
    if (-not (Test-Path -LiteralPath $fallbackProfileRoot -PathType Container)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $fallbackProfileRoot -Directory -Force -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName)
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $oneDriveExecutable = $OneDriveExecutableCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    $oneDriveVersion = if ($oneDriveExecutable) { (Get-Item -LiteralPath $oneDriveExecutable).VersionInfo.ProductVersion } else { '' }
    $profileSignals = @()

    $profilePaths = @(Get-TargetUserProfilePath)
    if ($profilePaths.Count -gt 0) {
        $profileSignals = @($profilePaths | ForEach-Object {
            $profilePath = [string]$_
            $oneDriveFolders = @(Get-ChildItem -LiteralPath $profilePath -Directory -Filter 'OneDrive*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
            [pscustomobject]@{
                ProfileName = Split-Path -Path $profilePath -Leaf
                ProfilePath = $profilePath
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

    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw "OneDrive state export '$outputPath' was not created."
    }

    $validatedPayload = Get-Content -LiteralPath $outputPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace([string]$validatedPayload.ComputerName) -or
        [string]::IsNullOrWhiteSpace([string]$validatedPayload.CapturedAt) -or
        $null -eq $validatedPayload.ProfileSignals) {
        throw "OneDrive state export '$outputPath' is missing required payload fields."
    }

    Write-Log -Message "OneDrive sync client state exported and validated at '$outputPath'."
    Write-Output "OneDrive sync client state exported and validated at '$outputPath'."
    exit 0
}
catch {
    try { Write-Log -Message "OneDrive sync client state export failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'OneDrive sync client state export failed.'
    exit 1
}
