<#
.SYNOPSIS
    Detects whether a folder exists and optionally checks an ACL entry.

.DESCRIPTION
    Intune Remediations detection script. The script checks a configurable
    folder path and optionally validates that a configured identity has a
    configured file-system right.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Folder and optional permission are compliant
    Exit 1:      Folder or optional permission is missing

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

$ScriptPackageName = 'Ensure-Folder-Exists-With-Permissions'
$ScriptName = 'Detect'

$FolderPath = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ExampleManagedFolder'
$ValidateAclEntry = $false
$AclIdentitySid = 'S-1-5-32-545'
$AclRight = 'ReadAndExecute'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log {
    param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO')
    Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8
}
function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

function ConvertTo-SidValue {
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Principal.IdentityReference]$IdentityReference
    )

    try {
        return $IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
    }
    catch {
        return $IdentityReference.Value
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. FolderPath='$FolderPath'; ValidateAclEntry='$ValidateAclEntry'."

    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
        Write-Output "Not compliant. Folder '$FolderPath' does not exist."
        exit 1
    }

    if ($ValidateAclEntry) {
        $acl = Get-Acl -LiteralPath $FolderPath
        $matchingRule = @($acl.Access | Where-Object {
            (ConvertTo-SidValue -IdentityReference $_.IdentityReference) -eq $AclIdentitySid -and
            $_.FileSystemRights.ToString() -like "*$AclRight*" -and
            $_.AccessControlType -eq 'Allow'
        })

        if ($matchingRule.Count -eq 0) {
            Write-Output "Not compliant. Folder '$FolderPath' is missing ACL SID '$AclIdentitySid' '$AclRight'."
            exit 1
        }
    }

    $message = "Compliant. Folder '$FolderPath' exists."
    Write-Log -Message $message
    Write-Output $message
    exit 0
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Not compliant. Folder '$FolderPath' could not be validated."
    exit 1
}
