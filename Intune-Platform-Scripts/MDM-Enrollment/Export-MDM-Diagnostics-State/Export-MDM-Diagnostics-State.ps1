<#
.SYNOPSIS
    Exports MDM Diagnostics state.

.DESCRIPTION
    Exports MDM Diagnostics state to a local JSON report for Intune platform script use.

.NOTES
    Name:        Export-MDM-Diagnostics-State.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune Platform Scripts
    Exit 0:      Export completed
    Exit 1:      Export did not complete

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

$ScriptPackageName = 'Export-MDM-Diagnostics-State'
$ScriptName = 'Export-MDM-Diagnostics-State'

$ManagedItemName = 'MDM Diagnostics'
$PurposeCategory = 'MDM-Enrollment'
$ReportRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Reports\MDM-Enrollment'
$ReportFileName = 'export-mdm-diagnostics-state.json'
$ExampleTenantDomain = 'contoso.com'
$ExampleVpnProfileName = 'ExampleVpn'
$ExamplePrinterName = 'PrinterName'

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
    Write-Log -Message "Export started. ManagedItemName='$ManagedItemName'; PurposeCategory='$PurposeCategory'."

    if (-not (Test-Path -LiteralPath $ReportRoot -PathType Container)) {
        New-Item -Path $ReportRoot -ItemType Directory -Force | Out-Null
    }

    $report = [ordered]@{
        ManagedItemName = $ManagedItemName
        PurposeCategory = $PurposeCategory
        ComputerName = $env:COMPUTERNAME
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ExampleTenantDomain = $ExampleTenantDomain
        Notes = 'Replace this snapshot block with tenant-approved collection logic before production deployment.'
    }

    $reportPath = Join-Path -Path $ReportRoot -ChildPath $ReportFileName
    $report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $reportPath -Encoding UTF8

    Write-Output "Export completed. '$ManagedItemName' report written to '$reportPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Export local error. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Export did not complete for '$ManagedItemName'."
    exit 1
}
