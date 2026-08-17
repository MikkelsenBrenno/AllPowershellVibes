<#
.SYNOPSIS
    <Short description of what this script does.>

.DESCRIPTION
    <Longer description of the intended Intune use case.>

.NOTES
    Name:        <ScriptName.ps1>
    Author:      <Author or team>
    Version:     1.0.0
    Created:     <YYYY-MM-DD>
    Updated:     <YYYY-MM-DD>
    PowerShell:  Windows PowerShell 5.1
    Context:     <System or User>

.INTUNE
    Workload:    <Remediation | Custom Compliance | Platform Script | Win32 App>
    Exit 0:      Remediation changed and verified the required state
    Exit 1:      Remediation or final-state validation failed

.CUSTOMIZATION
    Update values in the CONFIGURATION section before deployment.
#>

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

# =========================
# CONFIGURATION
# =========================

# CUSTOMIZE HERE.
$ScriptPackageName = '<Script-Folder-Name>'
$ScriptName = '<ScriptName>'
$DesiredValue = '<Expected compliant value>'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log {
    if (-not (Test-Path -LiteralPath $LogRoot -PathType Container)) {
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

    Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

function Set-DesiredState {
    # IMPLEMENT WORKLOAD LOGIC: change the same state evaluated by Detect.ps1.
    throw 'IMPLEMENT WORKLOAD LOGIC before using this template.'
}

function Get-ObservedValue {
    # IMPLEMENT WORKLOAD LOGIC: reread direct device evidence after the change.
    throw 'IMPLEMENT WORKLOAD LOGIC before using this template.'
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. Desired value is '$DesiredValue'."

    Set-DesiredState
    $actualValue = Get-ObservedValue

    if ($actualValue -ne $DesiredValue) {
        throw "Final-state validation observed '$actualValue'; expected '$DesiredValue'."
    }

    Write-Log -Message "Remediation succeeded and final state was verified as '$actualValue'."
    Write-Output "Remediation succeeded. Verified value is '$actualValue'."
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed or final state could not be verified.'
    exit 1
}
