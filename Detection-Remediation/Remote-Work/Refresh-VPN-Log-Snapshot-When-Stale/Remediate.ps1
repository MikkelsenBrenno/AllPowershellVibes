<#
.SYNOPSIS
    Remediates VPN Log Snapshot state.

.DESCRIPTION
    Detects and remediates VPN Log Snapshot state for Intune-managed Windows devices.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      VPN Log Snapshot remediation completed
    Exit 1:      VPN Log Snapshot remediation failed

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

$ScriptPackageName = 'Refresh-VPN-Log-Snapshot-When-Stale'
$ScriptName = 'Remediate'

$SnapshotName = 'VPN Log Snapshot'
$SnapshotRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Snapshots\Remote-Work'
$SnapshotFileName = 'vpn-log-snapshot-snapshot.json'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"
$script:LogAvailable = $false

function Initialize-Log {
    try {
        if (-not (Test-Path -LiteralPath $LogRoot -PathType Container)) {
            New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
        }

        $script:LogAvailable = $true
    }
    catch {
        $script:LogAvailable = $false
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    if (-not $script:LogAvailable) {
        return
    }

    try {
        Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8
    }
    catch {
        $script:LogAvailable = $false
    }
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. SnapshotName='$SnapshotName'; SnapshotFileName='$SnapshotFileName'."

    if (-not (Test-Path -LiteralPath $SnapshotRoot -PathType Container)) {
        New-Item -Path $SnapshotRoot -ItemType Directory -Force | Out-Null
    }

    $snapshotPath = Join-Path -Path $SnapshotRoot -ChildPath $SnapshotFileName
    $snapshot = [ordered]@{
        SnapshotName = $SnapshotName
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        Source = $ScriptPackageName
    }

    $snapshot | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $snapshotPath -Encoding UTF8
    Write-Output "Remediation completed. Snapshot '$SnapshotName' was written to '$snapshotPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation failed for snapshot '$SnapshotName'."
    exit 1
}
