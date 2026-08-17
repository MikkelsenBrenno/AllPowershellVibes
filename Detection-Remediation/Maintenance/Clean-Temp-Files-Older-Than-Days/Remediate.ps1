<#
.SYNOPSIS
    Deletes old files from configured cleanup paths.

.DESCRIPTION
    Intune Remediations remediation script. The script removes files older
    than the configured age from configured paths and validates whether old
    files remain.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Cleanup completed
    Exit 1:      Cleanup failed or old files remain

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
$ScriptName = 'Remediate'

# Change these paths for your cleanup scenario.
$CleanupPaths = @(
    (Join-Path -Path $env:SystemRoot -ChildPath 'Temp')
)

# Files older than this many days are cleanup candidates.
$MinimumFileAgeDays = 14
$Recurse = $false

# Safety switch. Set false for reporting-only pilot runs.
$DeleteCandidateFiles = $true

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
    Write-Log -Message "Remediation started. MinimumFileAgeDays='$MinimumFileAgeDays'; Recurse='$Recurse'; DeleteCandidateFiles='$DeleteCandidateFiles'."

    $candidateFiles = @(Get-CleanupCandidateFiles)
    Write-Log -Message "Candidate file count before cleanup: $($candidateFiles.Count)."

    if ($candidateFiles.Count -eq 0) {
        $message = 'Cleanup not required. No old files found.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    if (-not $DeleteCandidateFiles) {
        Write-Log -Message 'DeleteCandidateFiles is false. Reporting only.' -Level 'WARN'
        Write-Output "Cleanup candidates remain: $($candidateFiles.Count)."
        exit 1
    }

    foreach ($file in $candidateFiles) {
        try {
            Write-Log -Message "Removing '$($file.FullName)'."
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
        }
        catch {
            Write-Log -Message "Failed to remove '$($file.FullName)'. $($_.Exception.Message)" -Level 'WARN'
        }
    }

    $remainingCandidateFiles = @(Get-CleanupCandidateFiles)

    if ($remainingCandidateFiles.Count -eq 0) {
        $message = "Cleanup completed. Removed old files from configured paths."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Cleanup completed with remaining candidate files: $($remainingCandidateFiles.Count)."
    Write-Log -Message $message -Level 'ERROR'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Cleanup remediation failed.'
    exit 1
}
