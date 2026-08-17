<#
.SYNOPSIS
    Installs Camera Device package marker.

.DESCRIPTION
    Installs Camera Device as a reusable Win32 script package.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Package marker installed
    Exit 1:      Package install did not complete

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

$ScriptPackageName = 'Install-Camera-Device-Package'
$ScriptName = 'Install'

$ManagedItemName = 'Camera Device'
$PackageVersion = '1.0.0'
$InstallRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Win32Packages\Peripheral-Devices\Install-Camera-Device-Package'
$MarkerFileName = 'install-camera-device-package.state'
$PayloadFileName = 'package-info.json'
$ExampleTenantDomain = 'contoso.com'
$ExampleVpnProfileName = 'ExampleVpn'
$ExamplePrinterName = 'PrinterName'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"
$script:LogAvailable = $false

function Initialize-Log {
    try {
        if (-not (Test-Path -LiteralPath $LogRoot -PathType Container)) {
            New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
        }

        $script:LogAvailable = $true
    }
    catch {
        $script:LogAvailable = $false
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    if (-not $script:LogAvailable) {
        return
    }

    try {
        Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8
    }
    catch {
        $script:LogAvailable = $false
    }
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
    Write-Log -Message "Install started. ManagedItemName='$ManagedItemName'; PackageVersion='$PackageVersion'."

    if (-not (Test-Path -LiteralPath $InstallRoot -PathType Container)) {
        New-Item -Path $InstallRoot -ItemType Directory -Force | Out-Null
    }

    $payload = [ordered]@{
        ManagedItemName = $ManagedItemName
        PackageVersion = $PackageVersion
        InstalledAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        ExampleTenantDomain = $ExampleTenantDomain
    }

    $payload | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path -Path $InstallRoot -ChildPath $PayloadFileName) -Encoding UTF8
    Set-Content -LiteralPath (Join-Path -Path $InstallRoot -ChildPath $MarkerFileName) -Value $PackageVersion -Encoding UTF8

    Write-Output "Install completed. '$ManagedItemName' package version '$PackageVersion' installed."
    exit 0
}
catch {
    try { Write-Log -Message "Install local error. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output "Install did not complete for '$ManagedItemName'."
    exit 1
}
