<#
.SYNOPSIS
    Discovers Remote Assistance state for custom compliance.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks the Remote
    Assistance registry setting and returns one compressed JSON object.

.NOTES
    Name:        Discover.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Custom Compliance
    Output:      Compressed JSON

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

$ScriptPackageName = 'Check-Remote-Assistance-State'
$ScriptName = 'Discover'

$RemoteAssistanceRegistryPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance'
$AllowHelpValueName = 'fAllowToGetHelp'
$ExpectedAllowHelpValue = 0

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

$result = [ordered]@{
    RemoteAssistanceDisabled = $false
    RegistryPathExists = $false
    AllowHelpValueName = $AllowHelpValueName
    AllowHelpValue = -1
    ExpectedAllowHelpValue = [int]$ExpectedAllowHelpValue
}

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Test-Path -LiteralPath $RemoteAssistanceRegistryPath -PathType Container)) {
        throw "Registry path '$RemoteAssistanceRegistryPath' was not found."
    }

    $item = Get-ItemProperty -LiteralPath $RemoteAssistanceRegistryPath -Name $AllowHelpValueName -ErrorAction Stop
    $actualValue = [int]$item.$AllowHelpValueName

    $result.RegistryPathExists = $true
    $result.AllowHelpValue = $actualValue
    $result.RemoteAssistanceDisabled = ($actualValue -eq $ExpectedAllowHelpValue)

    Write-Log -Message "Discovery completed. Path='$RemoteAssistanceRegistryPath'; Value='$actualValue'; Expected='$ExpectedAllowHelpValue'; Disabled='$($result.RemoteAssistanceDisabled)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.RemoteAssistanceDisabled = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
