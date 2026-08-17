<#
.SYNOPSIS
    Detects Dock Driver state.

.DESCRIPTION
    Detects Dock Driver state for Intune remediation targeting.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Dock Driver is compliant
    Exit 1:      Dock Driver is noncompliant

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

$ScriptPackageName = 'Ensure-Dock-Driver-State'
$ScriptName = 'Detect'

$ManagedItemName = 'Dock Driver'
$PurposeCategory = 'Hardware-Drivers'
$ManagedStateRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ManagedState\Hardware-Drivers'
$MarkerFileName = 'ensure-dock-driver-state.state'
$ExpectedState = 'Configured'
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
    Write-Log -Message "Detection started. ManagedItemName='$ManagedItemName'; PurposeCategory='$PurposeCategory'; ExpectedState='$ExpectedState'."

    $markerPath = Join-Path -Path $ManagedStateRoot -ChildPath $MarkerFileName
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        Write-Output "Not compliant. '$ManagedItemName' state marker is not present."
        exit 1
    }

    $actualState = (Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop).Trim()
    if ($actualState -eq $ExpectedState) {
        Write-Output "Compliant. '$ManagedItemName' is '$ExpectedState'."
        exit 0
    }

    Write-Output "Not compliant. '$ManagedItemName' is '$actualState'; expected '$ExpectedState'."
    exit 1
}
catch {
    try { Write-Log -Message "Detection local error. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. '$ManagedItemName' local check returned no verified state."
    exit 1
}
