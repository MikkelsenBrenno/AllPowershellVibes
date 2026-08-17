<#
.SYNOPSIS
    Discovers WiFi Recovery Marker compliance state.

.DESCRIPTION
    Discovers WiFi Recovery Marker state for Intune custom compliance evaluation.

.NOTES
    Name:        Discover.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Custom Compliance
    Exit 0:      Discovery JSON was returned
    Exit 1:      Discovery failed

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

$ScriptPackageName = 'Check-WiFi-Recovery-Marker'
$ScriptName = 'Discover'

$ManagedItemName = 'WiFi Recovery Marker'
$MarkerRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ManagedState\Remote-Work'
$MarkerFileName = 'wifi-recovery-marker.state'
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

$result = [ordered]@{
    IsCompliant = $false
    ManagedItemName = $ManagedItemName
    ExpectedValue = $ExpectedMarkerValue
    ActualValue = ''
    EvidencePath = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $markerPath = Join-Path -Path $MarkerRoot -ChildPath $MarkerFileName
    $result.EvidencePath = $markerPath

    if (Test-Path -LiteralPath $markerPath -PathType Leaf) {
        $result.ActualValue = (Get-Content -LiteralPath $markerPath -Raw -ErrorAction Stop).Trim()
        $result.IsCompliant = ($result.ActualValue -eq $ExpectedMarkerValue)
    }
    else {
        $result.ActualValue = 'Missing'
    }

    Write-Log -Message "Discovery completed. ManagedItemName='$ManagedItemName'; IsCompliant='$($result.IsCompliant)'; ActualValue='$($result.ActualValue)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.IsCompliant = $false
    $result.ActualValue = 'Error'
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
