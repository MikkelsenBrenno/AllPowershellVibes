<#
.SYNOPSIS
    Detects whether expected Windows Update policy registry values exist.

.DESCRIPTION
    Intune Remediations detection script. The script checks a customizable
    list of policy registry values and returns noncompliance when any value is
    missing or different.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Expected policy values are present
    Exit 1:      One or more policy values are missing or different

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

$ScriptPackageName = 'Ensure-Windows-Update-Policy-Keys-Present'
$ScriptName = 'Detect'

$ExpectedRegistryValues = @(
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        Name = 'TargetReleaseVersion'
        Value = 1
    },
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        Name = 'TargetReleaseVersionInfo'
        Value = '24H2'
    }
)

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

try {
    Initialize-Log
    Write-ScriptMetadata

    $missingOrDifferent = @()

    foreach ($item in $ExpectedRegistryValues) {
        if (-not (Test-Path -LiteralPath $item.Path)) {
            $missingOrDifferent += "$($item.Path)\$($item.Name)"
            continue
        }

        $current = Get-ItemProperty -LiteralPath $item.Path -Name $item.Name -ErrorAction SilentlyContinue
        if ($null -eq $current -or [string]$current.$($item.Name) -ne [string]$item.Value) {
            $missingOrDifferent += "$($item.Path)\$($item.Name)"
        }
    }

    if ($missingOrDifferent.Count -eq 0) {
        $message = 'Compliant. Expected Windows Update policy values are present.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Missing or different values: $($missingOrDifferent -join ', ')."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Windows Update policy values could not be validated.'
    exit 1
}
