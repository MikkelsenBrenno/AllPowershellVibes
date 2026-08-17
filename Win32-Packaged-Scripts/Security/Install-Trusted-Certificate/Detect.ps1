<#
.SYNOPSIS
    Detects a trusted certificate by thumbprint.

.DESCRIPTION
    Win32 app custom detection script example. Intune considers the app
    detected only when this script exits 0 and writes STDOUT.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App Detection
    Exit 0:      Certificate detected, with STDOUT
    Exit 1:      Certificate missing

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

$ScriptPackageName = 'Install-Trusted-Certificate'
$ScriptName = 'Detect'

$ExpectedThumbprint = 'PASTE_CERTIFICATE_THUMBPRINT_HERE'
$CertificateStoreLocation = 'LocalMachine'
$CertificateStoreName = 'Root'

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
    if ($ExpectedThumbprint -eq 'PASTE_CERTIFICATE_THUMBPRINT_HERE' -or [string]::IsNullOrWhiteSpace($ExpectedThumbprint)) { throw 'ExpectedThumbprint must be customized.' }
    $normalizedThumbprint = ($ExpectedThumbprint -replace '\s', '').ToUpperInvariant()
    $certificatePath = "Cert:\$CertificateStoreLocation\$CertificateStoreName\$normalizedThumbprint"
    if (Test-Path -LiteralPath $certificatePath -PathType Leaf) {
        Write-Output "Detected. Certificate '$normalizedThumbprint' exists."
        exit 0
    }
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    exit 1
}
