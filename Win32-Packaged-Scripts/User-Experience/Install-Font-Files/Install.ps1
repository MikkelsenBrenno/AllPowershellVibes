<#
.SYNOPSIS
    Installs one or more font files.

.DESCRIPTION
    Win32 app install script example. The script copies configurable font
    files from the package folder into the Windows Fonts folder and writes
    matching font registry entries.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Installation succeeded
    Exit 1:      Installation failed

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
$ScriptName = 'Install'

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
        $sourcePath = Join-Path -Path $PSScriptRoot -ChildPath $font.FileName
        $destinationPath = Join-Path -Path $FontsFolder -ChildPath $font.FileName

        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Font source file '$sourcePath' was not found. Add the font file to the package folder or update the CONFIGURATION section."
        }

        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
        New-ItemProperty -Path $FontRegistryPath -Name $font.RegistryName -Value $font.FileName -PropertyType String -Force | Out-Null

        if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
            throw "Font copy validation failed for '$destinationPath'."
        }

        Write-Log -Message "Installed font. Source='$sourcePath'; Destination='$destinationPath'; RegistryName='$($font.RegistryName)'."
    }

    Write-Output "Install succeeded. Installed $($FontFiles.Count) font file(s)."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Install failed.'
    exit 1
}
