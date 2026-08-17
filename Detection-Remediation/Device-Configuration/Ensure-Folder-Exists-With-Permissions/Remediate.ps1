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
$AclIdentity = 'BUILTIN\Users'
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
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $AclIdentity,
            $AclRight,
            $InheritanceFlags,
            $PropagationFlags,
            'Allow'
        )
        $acl.SetAccessRule($rule)
        Set-Acl -LiteralPath $FolderPath -AclObject $acl
        Write-Log -Message "Configured ACL '$AclIdentity' '$AclRight'."
    }

    if (-not (Test-Path -LiteralPath $FolderPath -PathType Container)) {
        throw "Folder '$FolderPath' does not exist after remediation."
    }

    $message = "Remediation succeeded. Folder '$FolderPath' exists."
    Write-Log -Message $message
    Write-Output $message
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Remediation failed for folder '$FolderPath'."
    exit 1
}
