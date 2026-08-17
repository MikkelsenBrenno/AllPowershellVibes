<#
.SYNOPSIS
    Discovers whether a Wi-Fi profile is present.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks netsh WLAN
    profile output for a configurable profile name and returns one compressed
    JSON object.

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

$ScriptPackageName = 'Check-WiFi-Profile-Present'
$ScriptName = 'Discover'

$ExpectedWiFiProfileName = 'Contoso WiFi'

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
    WiFiProfilePresent = $false
    ExpectedWiFiProfileName = $ExpectedWiFiProfileName
    Profiles = @()
}

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Get-Command -Name netsh.exe -ErrorAction SilentlyContinue)) {
        throw 'netsh.exe is not available on this device.'
    }

    $profileOutput = @(netsh.exe wlan show profiles)
    $profiles = @()

    foreach ($line in $profileOutput) {
        if ($line -match ':\s*(.+)$') {
            $profileName = $matches[1].Trim()
            if (-not [string]::IsNullOrWhiteSpace($profileName)) {
                $profiles += $profileName
            }
        }
    }

    $result.Profiles = @($profiles | Sort-Object -Unique)
    $result.WiFiProfilePresent = ($result.Profiles -contains $ExpectedWiFiProfileName)

    Write-Log -Message "Discovery completed. ExpectedWiFiProfileName='$ExpectedWiFiProfileName'; Present='$($result.WiFiProfilePresent)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.WiFiProfilePresent = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
