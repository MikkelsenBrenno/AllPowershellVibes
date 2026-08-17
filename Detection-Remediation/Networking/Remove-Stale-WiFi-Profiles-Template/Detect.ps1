<#
.SYNOPSIS
    Detects stale saved Wi-Fi profiles.

.DESCRIPTION
    Intune Remediations detection script. The script compares saved Wi-Fi profiles with configured allowed names and prefixes.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      No stale Wi-Fi profiles found
    Exit 1:      Stale Wi-Fi profiles found

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

# Keep these names aligned with the folder and script file.
# Logs are written to Logs\<ScriptPackageName>\<ScriptName>.log.
$ScriptPackageName = 'Remove-Stale-WiFi-Profiles-Template'
$ScriptName = 'Detect'

$AllowedProfileNames = @('Contoso WiFi')
$AllowedProfilePrefixes = @('CORP-')

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
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

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

function Get-WiFiProfileName {
    if (-not (Get-Command -Name netsh.exe -ErrorAction SilentlyContinue)) {
        throw 'netsh.exe is not available on this device.'
    }

    $output = @(& netsh.exe wlan show profiles 2>&1)
    foreach ($line in $output) {
        if ($line -match 'Profile' -and $line -match ':\s*(?<Name>.+)$') {
            $name = $Matches.Name.Trim()
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                $name
            }
        }
    }
}

function Test-WiFiProfileAllowed {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($AllowedProfileNames -contains $Name) {
        return $true
    }

    foreach ($prefix in $AllowedProfilePrefixes) {
        if (-not [string]::IsNullOrWhiteSpace($prefix) -and $Name.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Get-StaleWiFiProfile {
    $profiles = @(Get-WiFiProfileName | Sort-Object -Unique)
    foreach ($profile in $profiles) {
        if (-not (Test-WiFiProfileAllowed -Name $profile)) {
            $profile
        }
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. AllowedProfileNames='$($AllowedProfileNames -join ',')'; AllowedProfilePrefixes='$($AllowedProfilePrefixes -join ',')'."

    $staleProfiles = @(Get-StaleWiFiProfile)
    if ($staleProfiles.Count -eq 0) {
        $message = 'Compliant. No stale Wi-Fi profiles were found.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Stale Wi-Fi profile(s) found: $($staleProfiles -join ', ')."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "$ScriptName failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Not compliant. Wi-Fi profiles could not be validated.'
    exit 1
}

