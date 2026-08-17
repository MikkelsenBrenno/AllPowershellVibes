<#
.SYNOPSIS
    Detects unauthorized local Administrators members.

.DESCRIPTION
    Intune Remediations detection script. The script checks the configured
    local group and exits 1 when members are present that are not in the
    allowed list.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Local administrator membership is compliant
    Exit 1:      Unauthorized local administrator members were found

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
$ScriptName = 'Detect'

# Built-in local Administrators group SID. The script resolves the localized
# group name at runtime before calling the LocalAccounts cmdlets.
$LocalAdministratorsGroupSid = 'S-1-5-32-544'
$FallbackLocalAdministratorsGroupName = 'Administrators'

# Allowed members. Use exact names when $CompareAccountNameOnly is $false.
# When $CompareAccountNameOnly is $true, DOMAIN\User and COMPUTER\User compare as User.
$AllowedLocalAdministratorMembers = @(
    'Administrator'
)
$CompareAccountNameOnly = $true

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

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. LocalAdministratorsGroupSid='$LocalAdministratorsGroupSid'; CompareAccountNameOnly='$CompareAccountNameOnly'."

    if (-not (Get-Command -Name Get-LocalGroupMember -ErrorAction SilentlyContinue)) {
        throw 'Get-LocalGroupMember is not available. Use 64-bit Windows PowerShell 5.1 on supported Windows builds.'
    }

    $localGroupName = Get-LocalAdministratorsGroupName
    $allowedComparableNames = @($AllowedLocalAdministratorMembers | ForEach-Object { ConvertTo-ComparableMemberName -Name $_ })
    $members = @(Get-LocalGroupMember -Group $localGroupName -ErrorAction Stop)
    $unauthorizedMembers = New-Object System.Collections.Generic.List[string]

    foreach ($member in $members) {
        $memberName = [string]$member.Name
        $comparableName = ConvertTo-ComparableMemberName -Name $memberName
        Write-Log -Message "Found local group member '$memberName'."

        if ($allowedComparableNames -notcontains $comparableName) {
            $unauthorizedMembers.Add($memberName)
        }
    }

    if ($unauthorizedMembers.Count -eq 0) {
        $message = "Compliant. No unauthorized members found in '$localGroupName'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Unauthorized members in '$localGroupName': $($unauthorizedMembers -join ', ')."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output "Not compliant. Local Administrators group could not be validated."
    exit 1
}
