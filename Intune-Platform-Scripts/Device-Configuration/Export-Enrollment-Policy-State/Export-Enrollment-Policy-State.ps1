<#
.SYNOPSIS
    Exports Enrollment Policy State state.

.DESCRIPTION
    Exports Enrollment Policy State state to a local JSON troubleshooting snapshot.

.NOTES
    Name:        Export-Enrollment-Policy-State.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune Platform Scripts
    Exit 0:      State snapshot was written
    Exit 1:      State snapshot export failed

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

$ScriptPackageName = 'Export-Enrollment-Policy-State'
$ScriptName = 'Export-Enrollment-Policy-State'

$ManagedItemName = 'Enrollment Policy State'
$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory\Device-Configuration'
$InventoryFileName = 'enrollment-policy-state-snapshot.json'
$EvidenceRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ManagedState\Device-Configuration'
$EvidenceFileName = 'enrollment-policy-state.state'

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
    Write-Log -Message "Script started. ManagedItemName='$ManagedItemName'; InventoryFileName='$InventoryFileName'."

    if (-not (Test-Path -LiteralPath $InventoryRoot -PathType Container)) {
        New-Item -Path $InventoryRoot -ItemType Directory -Force | Out-Null
    }

    $evidencePath = Join-Path -Path $EvidenceRoot -ChildPath $EvidenceFileName
    $evidencePresent = Test-Path -LiteralPath $evidencePath -PathType Leaf
    $evidenceValue = if ($evidencePresent) { (Get-Content -LiteralPath $evidencePath -Raw -ErrorAction SilentlyContinue).Trim() } else { 'Missing' }

    $snapshot = [ordered]@{
        ManagedItemName = $ManagedItemName
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        EvidencePath = $evidencePath
        EvidencePresent = $evidencePresent
        EvidenceValue = $evidenceValue
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $snapshot | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    Write-Output "State snapshot for '$ManagedItemName' written to '$inventoryPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Failed to export state for '$ManagedItemName'."
    exit 1
}
