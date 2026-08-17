<#
.SYNOPSIS
    Detects installed font files.

.DESCRIPTION
    Win32 app detection script example. The script checks that each
    configured font file exists in the Windows Fonts folder and has a
    matching registry entry.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Fonts detected
    Exit 1:      Fonts missing

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
$ScriptName = 'Detect'

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

    $registryProperties = Get-ItemProperty -LiteralPath $FontRegistryPath -ErrorAction Stop
    $missingItems = New-Object System.Collections.Generic.List[string]

    foreach ($font in $FontFiles) {
        $destinationPath = Join-Path -Path $FontsFolder -ChildPath $font.FileName
        $registryValue = $registryProperties.PSObject.Properties[$font.RegistryName].Value

        if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
            $missingItems.Add("Missing font file '$destinationPath'")
        }

        if ($registryValue -ne $font.FileName) {
            $missingItems.Add("Missing registry value '$($font.RegistryName)'")
        }
    }

    if ($missingItems.Count -eq 0) {
        Write-Output "Detected. Installed $($FontFiles.Count) font file(s)."
        exit 0
    }

    Write-Output "Not detected. $($missingItems -join '; ')."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not detected. Font state could not be validated.'
    exit 1
}
