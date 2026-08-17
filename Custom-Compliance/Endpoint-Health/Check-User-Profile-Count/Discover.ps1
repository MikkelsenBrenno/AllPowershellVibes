<#
.SYNOPSIS
    Discovers local user profile count for custom compliance.

.DESCRIPTION
    Intune custom compliance discovery script. The script counts local user
    profiles and returns one compressed JSON object to identify profile buildup
    on shared or long-lived devices.

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

$ScriptPackageName = 'Check-User-Profile-Count'
$ScriptName = 'Discover'

$MaximumUserProfileCount = 20
$IgnoreSpecialProfiles = $true
$IgnoredProfilePathPatterns = @(
    '*\Windows\ServiceProfiles\*',
    '*\Windows\system32\config\systemprofile'
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

function Test-ProfilePathIgnored {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    foreach ($pattern in $IgnoredProfilePathPatterns) {
        if ($Path -like $pattern) {
            return $true
        }
    }

    return $false
}

# =========================
# MAIN
# =========================

$result = [ordered]@{
    UserProfileCountCompliant = $false
    UserProfileCount = 0
    MaximumUserProfileCount = [int]$MaximumUserProfileCount
    ProfilePaths = @()
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $profiles = @(Get-CimInstance -ClassName Win32_UserProfile -ErrorAction Stop |
        Where-Object {
            (-not $IgnoreSpecialProfiles -or -not [bool]$_.Special) -and
            -not [string]::IsNullOrWhiteSpace([string]$_.LocalPath) -and
            -not (Test-ProfilePathIgnored -Path ([string]$_.LocalPath))
        })

    $profilePaths = @($profiles | ForEach-Object { [string]$_.LocalPath } | Sort-Object)

    $result.UserProfileCount = [int]$profilePaths.Count
    $result.ProfilePaths = $profilePaths
    $result.UserProfileCountCompliant = ($result.UserProfileCount -le $MaximumUserProfileCount)

    Write-Log -Message "Discovery completed. ProfileCount='$($result.UserProfileCount)'; Maximum='$MaximumUserProfileCount'; Compliant='$($result.UserProfileCountCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.UserProfileCountCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
