<#
.SYNOPSIS
    Uninstalls one or more font files.

.DESCRIPTION
    Win32 app uninstall script example. The script removes configurable font
    files from the Windows Fonts folder and removes matching registry values.

.NOTES
    Name:        Uninstall.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Uninstall succeeded
    Exit 1:      Uninstall failed

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

$ScriptPackageName = 'Install-Font-Files'
$ScriptName = 'Uninstall'

$FontsFolder = Join-Path -Path $env:SystemRoot -ChildPath 'Fonts'
$FontRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$FontFiles = @(
    [pscustomobject]@{
        FileName = 'ExampleFont.ttf'
        RegistryName = 'Example Font (TrueType)'
    }
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

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    foreach ($font in $FontFiles) {
        $destinationPath = Join-Path -Path $FontsFolder -ChildPath $font.FileName

        if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
            Remove-Item -LiteralPath $destinationPath -Force -ErrorAction Stop
            Write-Log -Message "Removed font file '$destinationPath'."
        }

        $registryProperties = Get-ItemProperty -LiteralPath $FontRegistryPath -ErrorAction SilentlyContinue
        if ($null -ne $registryProperties -and $null -ne $registryProperties.PSObject.Properties[$font.RegistryName]) {
            Remove-ItemProperty -LiteralPath $FontRegistryPath -Name $font.RegistryName -ErrorAction Stop
            Write-Log -Message "Removed font registry value '$($font.RegistryName)'."
        }
    }

    Write-Output "Uninstall succeeded. Removed configured font file(s) when present."
    exit 0
}
catch {
    try { Write-Log -Message "Uninstall failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Uninstall failed.'
    exit 1
}
