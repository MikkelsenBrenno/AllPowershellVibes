<#
.SYNOPSIS
    Exports WMI repository status.

.DESCRIPTION
    Intune platform script example. The script runs winmgmt repository
    verification and writes a JSON snapshot for technician troubleshooting.

.NOTES
    Name:        Export-WMI-Repository-Status.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      WMI repository snapshot written
    Exit 1:      Snapshot export failed

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

$ScriptPackageName = 'Export-WMI-Repository-Status'
$ScriptName = 'Export-WMI-Repository-Status'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'WmiRepositoryStatus.json'
$WinMgmtPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\wbem\winmgmt.exe'

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

    if (-not (Test-Path -LiteralPath $InventoryRoot -PathType Container)) {
        New-Item -Path $InventoryRoot -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $WinMgmtPath -PathType Leaf)) {
        throw "winmgmt.exe was not found at '$WinMgmtPath'."
    }

    $output = @(& $WinMgmtPath /verifyrepository 2>&1)
    $exitCode = $LASTEXITCODE
    $joinedOutput = ($output -join ' ').Trim()

    $snapshot = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        WinMgmtPath = $WinMgmtPath
        ExitCode = $exitCode
        Output = $joinedOutput
        RepositoryConsistent = ($joinedOutput -like '*consistent*')
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $snapshot | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    Write-Output "WMI repository status written to '$inventoryPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export WMI repository status.'
    exit 1
}
