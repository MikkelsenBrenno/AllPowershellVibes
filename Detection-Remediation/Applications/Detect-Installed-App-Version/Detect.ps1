<#
.SYNOPSIS
    Detects whether an installed application meets a minimum version.

.DESCRIPTION
    Intune Remediations detection script. The script searches common Windows
    uninstall registry locations for an application display name and compares
    the installed version with a configured minimum version.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Application is installed and meets the minimum version
    Exit 1:      Application is missing, older than expected, or cannot be validated

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

$ScriptPackageName = 'Detect-Installed-App-Version'
$ScriptName = 'Detect'

# Use wildcards when the display name can vary by channel or edition.
$AppDisplayNamePattern = 'Google Chrome*'
$MinimumVersion = '120.0.0.0'

# Common machine-wide uninstall locations. Add HKCU only for user-context scripts.
$UninstallRegistryPaths = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)

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
    Add-Content -Path $LogPath -Value "$timestamp [$Level] $Message" -Encoding UTF8
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

function ConvertTo-VersionOrNull {
    param(
        [AllowEmptyString()]
        [string]$VersionText
    )

    try {
        return [version]$VersionText
    }
    catch {
        return $null
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. AppDisplayNamePattern='$AppDisplayNamePattern'; MinimumVersion='$MinimumVersion'."

    $minimumVersionObject = ConvertTo-VersionOrNull -VersionText $MinimumVersion

    if ($null -eq $minimumVersionObject) {
        throw "MinimumVersion '$MinimumVersion' is not a valid version."
    }

    $matches = New-Object System.Collections.Generic.List[object]

    foreach ($path in $UninstallRegistryPaths) {
        $items = @(Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.DisplayName) -and
            $_.DisplayName -like $AppDisplayNamePattern
        })

        foreach ($item in $items) {
            $matches.Add($item)
        }
    }

    if ($matches.Count -eq 0) {
        Write-Log -Message "Application matching '$AppDisplayNamePattern' was not found." -Level 'WARN'
        Write-Output "Not compliant. Application matching '$AppDisplayNamePattern' was not found."
        exit 1
    }

    foreach ($match in $matches) {
        $displayName = [string]$match.DisplayName
        $displayVersion = [string]$match.DisplayVersion
        $installedVersionObject = ConvertTo-VersionOrNull -VersionText $displayVersion
        Write-Log -Message "Found application. DisplayName='$displayName'; DisplayVersion='$displayVersion'."

        if ($null -ne $installedVersionObject -and $installedVersionObject -ge $minimumVersionObject) {
            $message = "Compliant. '$displayName' version '$displayVersion' meets minimum '$MinimumVersion'."
            Write-Log -Message $message
            Write-Output $message
            exit 0
        }
    }

    Write-Log -Message "No matching application met minimum version '$MinimumVersion'." -Level 'WARN'
    Write-Output "Not compliant. Application matching '$AppDisplayNamePattern' is below minimum version '$MinimumVersion'."
    exit 1
}
catch {
    try {
        Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output "Not compliant. Application version could not be validated."
    exit 1
}
