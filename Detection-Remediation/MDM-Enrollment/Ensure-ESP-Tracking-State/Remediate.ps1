<#
.SYNOPSIS
    Remediates ESP Tracking state.

.DESCRIPTION
    Writes configurable state evidence for ESP Tracking remediation.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      ESP Tracking remediation completed
    Exit 1:      ESP Tracking remediation did not complete

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

$ScriptPackageName = 'Ensure-ESP-Tracking-State'
$ScriptName = 'Remediate'

$ManagedItemName = 'ESP Tracking'
$PurposeCategory = 'MDM-Enrollment'
$ManagedStateRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ManagedState\MDM-Enrollment'
$MarkerFileName = 'ensure-esp-tracking-state.state'
$EvidenceFileName = 'ensure-esp-tracking-state.json'
$DesiredState = 'Configured'
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
    Write-Log -Message "Remediation started. ManagedItemName='$ManagedItemName'; DesiredState='$DesiredState'."

    if (-not (Test-Path -LiteralPath $ManagedStateRoot -PathType Container)) {
        New-Item -Path $ManagedStateRoot -ItemType Directory -Force | Out-Null
    }

    $evidence = [ordered]@{
        ManagedItemName = $ManagedItemName
        PurposeCategory = $PurposeCategory
        DesiredState = $DesiredState
        UpdatedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
    }

    $evidence | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path -Path $ManagedStateRoot -ChildPath $EvidenceFileName) -Encoding UTF8
    Set-Content -LiteralPath (Join-Path -Path $ManagedStateRoot -ChildPath $MarkerFileName) -Value $DesiredState -Encoding UTF8

    Write-Output "Remediation completed. '$ManagedItemName' state marker was set to '$DesiredState'."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation local error. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation did not complete for '$ManagedItemName'."
    exit 1
}
