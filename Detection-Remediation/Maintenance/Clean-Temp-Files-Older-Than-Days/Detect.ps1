<#
.SYNOPSIS
    Detects old files in configured cleanup paths.

.DESCRIPTION
    Intune Remediations detection script. The script checks one or more
    configured paths for files older than the configured age and exits 1
    when cleanup should run.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      No cleanup required
    Exit 1:      Old files were found

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

$ScriptPackageName = 'Clean-Temp-Files-Older-Than-Days'
$ScriptName = 'Detect'

# Change these paths for your cleanup scenario.
$CleanupPaths = @(
    (Join-Path -Path $env:SystemRoot -ChildPath 'Temp')
)

# Files older than this many days are considered cleanup candidates.
$MinimumFileAgeDays = 14
$Recurse = $false

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

function Get-CleanupCandidateFiles {
    $cutoff = (Get-Date).AddDays(-$MinimumFileAgeDays)
    $candidateFiles = New-Object System.Collections.Generic.List[object]

    foreach ($cleanupPath in $CleanupPaths) {
        if (-not (Test-Path -LiteralPath $cleanupPath -PathType Container)) {
            Write-Log -Message "Cleanup path '$cleanupPath' does not exist." -Level 'WARN'
            continue
        }

        $getChildItemParameters = @{
            LiteralPath = $cleanupPath
            File = $true
            Force = $true
            ErrorAction = 'SilentlyContinue'
        }

        if ($Recurse) {
            $getChildItemParameters.Recurse = $true
        }

        $files = @(Get-ChildItem @getChildItemParameters | Where-Object { $_.LastWriteTime -lt $cutoff })
        Write-Log -Message "Cleanup path '$cleanupPath' has '$($files.Count)' files older than '$MinimumFileAgeDays' days."

        foreach ($file in $files) {
            $candidateFiles.Add($file)
        }
    }

    return @($candidateFiles)
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. MinimumFileAgeDays='$MinimumFileAgeDays'; Recurse='$Recurse'; CleanupPaths='$($CleanupPaths -join ',')'."

    $candidateFiles = @(Get-CleanupCandidateFiles)

    if ($candidateFiles.Count -eq 0) {
        $message = 'Compliant. No old cleanup candidate files found.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Cleanup candidate files found: $($candidateFiles.Count)."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Not compliant. Cleanup detection could not complete.'
    exit 1
}
