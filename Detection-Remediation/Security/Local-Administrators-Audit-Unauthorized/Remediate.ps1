<#
.SYNOPSIS
    Reports or removes unauthorized local Administrators members.

.DESCRIPTION
    Intune Remediations remediation script. The script finds unauthorized
    local group members and can optionally remove them. Removal is disabled
    by default so technicians must intentionally enable it.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      No unauthorized members remain
    Exit 1:      Unauthorized members remain or remediation failed

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
$ScriptPackageName = 'Local-Administrators-Audit-Unauthorized'
$ScriptName = 'Remediate'

# Built-in local Administrators group SID. The script resolves the localized
# group name at runtime before calling the LocalAccounts cmdlets.
$LocalAdministratorsGroupSid = 'S-1-5-32-544'
$FallbackLocalAdministratorsGroupName = 'Administrators'

# Allowed members. Use exact names when $CompareAccountNameOnly is $false.
$AllowedLocalAdministratorMembers = @(
    'Administrator'
)
$CompareAccountNameOnly = $true

# Safety switch. Keep false for audit-only mode. Set true only after pilot testing.
$RemoveUnauthorizedMembers = $false

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

function ConvertTo-ComparableMemberName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $trimmedName = $Name.Trim()

    if ($CompareAccountNameOnly -and $trimmedName -match '\\') {
        $trimmedName = ($trimmedName -split '\\')[-1]
    }

    return $trimmedName.ToUpperInvariant()
}

function Get-LocalAdministratorsGroupName {
    try {
        $sid = New-Object System.Security.Principal.SecurityIdentifier($LocalAdministratorsGroupSid)
        $account = $sid.Translate([System.Security.Principal.NTAccount])
        return ([string]$account.Value -split '\\')[-1]
    }
    catch {
        Write-Log -Message "Could not translate Administrators SID '$LocalAdministratorsGroupSid'. Falling back to '$FallbackLocalAdministratorsGroupName'. $($_.Exception.Message)" -Level 'WARN'
        return $FallbackLocalAdministratorsGroupName
    }
}

function Get-UnauthorizedLocalGroupMembers {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LocalGroupName
    )

    $allowedComparableNames = @($AllowedLocalAdministratorMembers | ForEach-Object { ConvertTo-ComparableMemberName -Name $_ })
    $members = @(Get-LocalGroupMember -Group $LocalGroupName -ErrorAction Stop)
    $unauthorizedMembers = New-Object System.Collections.Generic.List[object]

    foreach ($member in $members) {
        $memberName = [string]$member.Name
        $comparableName = ConvertTo-ComparableMemberName -Name $memberName
        Write-Log -Message "Found local group member '$memberName'."

        if ($allowedComparableNames -notcontains $comparableName) {
            $unauthorizedMembers.Add($member)
        }
    }

    return @($unauthorizedMembers)
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. LocalAdministratorsGroupSid='$LocalAdministratorsGroupSid'; RemoveUnauthorizedMembers='$RemoveUnauthorizedMembers'."

    if (-not (Get-Command -Name Get-LocalGroupMember -ErrorAction SilentlyContinue)) {
        throw 'Get-LocalGroupMember is not available. Use 64-bit Windows PowerShell 5.1 on supported Windows builds.'
    }

    if (-not (Get-Command -Name Remove-LocalGroupMember -ErrorAction SilentlyContinue)) {
        throw 'Remove-LocalGroupMember is not available. Use 64-bit Windows PowerShell 5.1 on supported Windows builds.'
    }

    $localGroupName = Get-LocalAdministratorsGroupName
    $unauthorizedMembers = @(Get-UnauthorizedLocalGroupMembers -LocalGroupName $localGroupName)

    if ($unauthorizedMembers.Count -eq 0) {
        $message = "No unauthorized members found in '$localGroupName'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $unauthorizedNames = (($unauthorizedMembers | ForEach-Object { [string]$_.Name }) -join ', ')
    Write-Log -Message "Unauthorized members found: $unauthorizedNames." -Level 'WARN'

    if (-not $RemoveUnauthorizedMembers) {
        Write-Log -Message 'Audit-only mode is enabled. Set RemoveUnauthorizedMembers to true after pilot testing to remove members.' -Level 'WARN'
        Write-Output "Unauthorized local administrators remain: $unauthorizedNames."
        exit 1
    }

    foreach ($member in $unauthorizedMembers) {
        Write-Log -Message "Removing unauthorized member '$($member.Name)' from '$localGroupName'."
        Remove-LocalGroupMember -Group $localGroupName -Member $member.Name -ErrorAction Stop
    }

    $remainingUnauthorizedMembers = @(Get-UnauthorizedLocalGroupMembers -LocalGroupName $localGroupName)

    if ($remainingUnauthorizedMembers.Count -eq 0) {
        $message = "Remediation succeeded. Unauthorized members removed from '$localGroupName'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $remainingNames = (($remainingUnauthorizedMembers | ForEach-Object { [string]$_.Name }) -join ', ')
    Write-Log -Message "Remediation failed. Unauthorized members remain: $remainingNames." -Level 'ERROR'
    Write-Output "Unauthorized local administrators remain: $remainingNames."
    exit 1
}
catch {
    try {
        Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Remediation failed for the local Administrators group.'
    exit 1
}
