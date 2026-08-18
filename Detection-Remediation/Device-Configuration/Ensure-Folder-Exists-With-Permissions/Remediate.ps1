<#
.SYNOPSIS
    Creates a folder and optionally grants a file-system permission.

.DESCRIPTION
    Intune Remediations remediation script. The script creates a configurable
    folder path and optionally adds a configured allow ACL entry.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Folder and optional permission are compliant
    Exit 1:      Folder or optional permission could not be configured

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
$ScriptName = 'Remediate'

$FolderPath = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\ExampleManagedFolder'
$ConfigureAclEntry = $false
$AclIdentitySid = 'S-1-5-32-545'
$AclRight = 'ReadAndExecute'
$InheritanceFlags = 'ContainerInherit,ObjectInherit'
$PropagationFlags = 'None'

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
    Write-Log -Message "Remediation started. FolderPath='$FolderPath'; ConfigureAclEntry='$ConfigureAclEntry'."

    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
        New-Item -Path $FolderPath -ItemType Directory -Force | Out-Null
        Write-Log -Message "Created folder '$FolderPath'."
    }

    if ($ConfigureAclEntry) {
        $acl = Get-Acl -LiteralPath $FolderPath
        $aclIdentity = New-Object System.Security.Principal.SecurityIdentifier($AclIdentitySid)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $aclIdentity,
            $AclRight,
            $InheritanceFlags,
            $PropagationFlags,
            'Allow'
        )
        $acl.SetAccessRule($rule)
        Set-Acl -LiteralPath $FolderPath -AclObject $acl
        Write-Log -Message "Configured ACL SID '$AclIdentitySid' '$AclRight'."
    }

    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
        throw "Folder '$FolderPath' does not exist after remediation."
    }

    if ($ConfigureAclEntry) {
        $finalAcl = Get-Acl -LiteralPath $FolderPath
        $matchingRule = @($finalAcl.Access | Where-Object {
            (ConvertTo-SidValue -IdentityReference $_.IdentityReference) -eq $AclIdentitySid -and
            $_.FileSystemRights.ToString() -like "*$AclRight*" -and
            $_.AccessControlType -eq 'Allow'
        })

        if ($matchingRule.Count -eq 0) {
            throw "Folder '$FolderPath' is missing ACL SID '$AclIdentitySid' '$AclRight' after remediation."
        }
    }

    $message = "Remediation succeeded. Folder '$FolderPath' and its configured ACL state are compliant."
    Write-Log -Message $message
    Write-Output $message
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation failed for folder '$FolderPath'."
    exit 1
}
