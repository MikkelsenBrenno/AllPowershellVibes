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
    Exit 0:      One compressed JSON object was returned
    Exit 1:      Discovery failed and no trustworthy result was returned

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

function Get-ObservedValue {
    # IMPLEMENT WORKLOAD LOGIC: discover a real value without changing the managed state.
    throw 'IMPLEMENT WORKLOAD LOGIC before using this template.'
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $result = [ordered]@{
        ExampleSetting = Get-ObservedValue
    }

    Write-Log -Message 'Custom Compliance discovery completed.'

    # Keep this as the only standard-output path. SettingName in ComplianceRules.json
    # must exactly match each returned property, including case.
    Write-Output ($result | ConvertTo-Json -Compress)
    exit 0
}
catch {
    try { Write-Log -Message "Custom Compliance discovery failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    exit 1
}
