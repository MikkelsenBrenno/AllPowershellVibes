<#
.SYNOPSIS
    Removes stale saved Wi-Fi profiles.

.DESCRIPTION
    Intune Remediations remediation script. The script deletes stale saved Wi-Fi profiles only when the safety toggle is enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Wi-Fi profile cleanup completed or reported
    Exit 1:      Wi-Fi profile cleanup failed

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
$ScriptName = 'Remediate'

$AllowedProfileNames = @('Contoso WiFi')
$AllowedProfilePrefixes = @('CORP-')
$RemoveStaleProfiles = $false
$ValidationDelaySeconds = 2

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
    Write-Log -Message "Remediation started. RemoveStaleProfiles='$RemoveStaleProfiles'."

    $staleProfiles = @(Get-StaleWiFiProfile)
    if ($staleProfiles.Count -eq 0) {
        $message = 'Remediation not required. No stale Wi-Fi profiles were found.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    if (-not $RemoveStaleProfiles) {
        $message = "Report-only mode. Set `$RemoveStaleProfiles to `$true to delete stale Wi-Fi profiles: $($staleProfiles -join ', ')."
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message
        exit 0
    }

    foreach ($profile in $staleProfiles) {
        Write-Log -Message "Deleting Wi-Fi profile '$profile'."
        & netsh.exe wlan delete profile name="$profile" | Out-Null
    }

    Start-Sleep -Seconds $ValidationDelaySeconds
    $remainingProfiles = @(Get-StaleWiFiProfile)
    if ($remainingProfiles.Count -eq 0) {
        $message = 'Remediation succeeded. Stale Wi-Fi profiles were removed.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. Stale Wi-Fi profile(s) remain: $($remainingProfiles -join ', ')."
    Write-Log -Message $message -Level 'ERROR'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "$ScriptName failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Remediation failed for stale Wi-Fi profiles.'
    exit 1
}

