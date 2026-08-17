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
    Exit 0:      The standalone action completed and was validated
    Exit 1:      The action or validation failed

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

function Invoke-PlatformAction {
    # IMPLEMENT WORKLOAD LOGIC: perform one complete standalone action.
    throw 'IMPLEMENT WORKLOAD LOGIC before using this template.'
}

function Test-PlatformResult {
    # IMPLEMENT WORKLOAD LOGIC: return $true only when the intended result is present.
    throw 'IMPLEMENT WORKLOAD LOGIC before using this template.'
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message 'Platform script action started.'

    Invoke-PlatformAction
    if (-not (Test-PlatformResult)) {
        throw 'The standalone action completed, but final-state validation failed.'
    }

    Write-Log -Message 'Platform script action completed and was validated.'
    Write-Output 'Platform script action completed successfully.'
    exit 0
}
catch {
    try { Write-Log -Message "Platform script action failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Platform script action failed.'
    exit 1
}
