<#
.SYNOPSIS
    Installs a trusted certificate.

.DESCRIPTION
    Win32 app install script example. The script imports a certificate file
    from the package folder into a configured certificate store.

.NOTES
    Name:        Install.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Win32 App
    Exit 0:      Certificate installed and detected
    Exit 1:      Certificate could not be installed

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
$ScriptName = 'Install'

$CertificateFileName = 'TrustedRootExample.cer'
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
    $certificatePath = Join-Path -Path $PSScriptRoot -ChildPath $CertificateFileName
    $storePath = "Cert:\$CertificateStoreLocation\$CertificateStoreName"
    Write-Log -Message "Install started. CertificatePath='$certificatePath'; StorePath='$storePath'."

    if (-not (Test-Path -LiteralPath $certificatePath -PathType Leaf)) { throw "Certificate file '$certificatePath' was not found." }

    $certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certificatePath)
    Import-Certificate -FilePath $certificatePath -CertStoreLocation $storePath -ErrorAction Stop | Out-Null

    if (-not (Test-Path -LiteralPath (Join-Path -Path $storePath -ChildPath $certificate.Thumbprint))) {
        throw "Certificate '$($certificate.Thumbprint)' was not found after import."
    }

    Write-Output "Certificate installed. Thumbprint='$($certificate.Thumbprint)'."
    exit 0
}
catch {
    try { Write-Log -Message "Install failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Certificate install failed.'
    exit 1
}
