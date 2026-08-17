<#
.SYNOPSIS
    Detects VPN Profile State state.

.DESCRIPTION
    Detects and remediates VPN Profile State state for Intune-managed Windows devices.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      VPN Profile State is compliant
    Exit 1:      VPN Profile State is noncompliant

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

$ScriptPackageName = 'Ensure-VPN-Profile-State'
$ScriptName = 'Detect'

$ManagedItemName = 'VPN Profile State'
$MarkerRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ManagedState\Remote-Work'
$MarkerFileName = 'vpn-profile-state.state'
$ExpectedMarkerValue = 'Configured'

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
    Write-Log -Message "Detection started. ManagedItemName='$ManagedItemName'; MarkerFileName='$MarkerFileName'; ExpectedMarkerValue='$ExpectedMarkerValue'."

    $markerPath = Join-Path -Path $MarkerRoot -ChildPath $MarkerFileName
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        Write-Output "Not compliant. Marker '$markerPath' is missing for '$ManagedItemName'."
        exit 1
    }

    $actualValue = (Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop).Trim()
    if ($actualValue -eq $ExpectedMarkerValue) {
        Write-Output "Compliant. Marker for '$ManagedItemName' is present."
        exit 0
    }

    Write-Output "Not compliant. Marker for '$ManagedItemName' is '$actualValue'; expected '$ExpectedMarkerValue'."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. Marker for '$ManagedItemName' could not be validated."
    exit 1
}
