<#
.SYNOPSIS
    Discovers local administrator count for custom compliance.

.DESCRIPTION
    Intune custom compliance discovery script. The script counts members of
    the built-in local Administrators group and returns one compressed JSON
    object for compliance evaluation and troubleshooting.

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

$ScriptPackageName = 'Check-Local-Administrator-Count'
$ScriptName = 'Discover'

$MaximumAllowedAdministrators = 2
$UseWellKnownAdministratorsSid = $true
$FallbackAdministratorsGroupName = 'Administrators'
$ExcludedMemberNamePatterns = @()

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Get-AdministratorsGroupName {
    if ($UseWellKnownAdministratorsSid) {
        try {
            $sid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
            $account = $sid.Translate([System.Security.Principal.NTAccount]).Value
            return ($account -split '\\')[-1]
        }
        catch {
            Write-Log -Message "Could not translate Administrators SID. Falling back to '$FallbackAdministratorsGroupName'. $($_.Exception.Message)" -Level 'WARN'
        }
    }

    return $FallbackAdministratorsGroupName
}

function Test-MemberExcluded {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    foreach ($pattern in $ExcludedMemberNamePatterns) {
        if ($Name -like $pattern) {
            return $true
        }
    }

    return $false
}

# =========================
# MAIN
# =========================

$result = [ordered]@{
    LocalAdministratorCountCompliant = $false
    LocalAdministratorCount = 0
    MaximumAllowedAdministrators = [int]$MaximumAllowedAdministrators
    LocalAdministratorsGroupName = ''
    LocalAdministratorMembers = @()
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $groupName = Get-AdministratorsGroupName
    $members = @(Get-LocalGroupMember -Group $groupName -ErrorAction Stop)
    $includedMembers = @(
        $members |
            ForEach-Object { [string]$_.Name } |
            Where-Object { -not (Test-MemberExcluded -Name $_) } |
            Sort-Object
    )

    $result.LocalAdministratorsGroupName = $groupName
    $result.LocalAdministratorMembers = @($includedMembers)
    $result.LocalAdministratorCount = [int]$includedMembers.Count
    $result.LocalAdministratorCountCompliant = ($result.LocalAdministratorCount -le $MaximumAllowedAdministrators)

    Write-Log -Message "Discovery completed. Group='$groupName'; Count='$($result.LocalAdministratorCount)'; Maximum='$MaximumAllowedAdministrators'; Compliant='$($result.LocalAdministratorCountCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.LocalAdministratorCountCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
