<#
.SYNOPSIS
    Discovers whether a certificate thumbprint exists.

.DESCRIPTION
    Intune custom compliance discovery script. The script searches one or
    more certificate stores for a configurable certificate thumbprint and
    returns one compressed JSON object.

.NOTES
    Name:        Discover.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Custom Compliance
    Output:      Compressed JSON

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

$ScriptPackageName = 'Check-Certificate-By-Thumbprint'
$ScriptName = 'Discover'

$ExpectedThumbprint = '0000000000000000000000000000000000000000'
$CertificateStorePaths = @(
    'Cert:\LocalMachine\Root',
    'Cert:\LocalMachine\CA',
    'Cert:\LocalMachine\My'
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

$result = [ordered]@{
    CertificateThumbprintPresent = $false
    CertificateStorePath = ''
    CertificateSubject = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata
    $normalizedExpectedThumbprint = ($ExpectedThumbprint -replace '\s', '').ToUpperInvariant()

    foreach ($storePath in $CertificateStorePaths) {
        $certificate = Get-ChildItem -LiteralPath $storePath -ErrorAction SilentlyContinue |
            Where-Object { ($_.Thumbprint -replace '\s', '').ToUpperInvariant() -eq $normalizedExpectedThumbprint } |
            Select-Object -First 1

        if ($null -ne $certificate) {
            $result.CertificateThumbprintPresent = $true
            $result.CertificateStorePath = $storePath
            $result.CertificateSubject = [string]$certificate.Subject
            break
        }
    }

    Write-Log -Message "Discovery completed. Thumbprint='$normalizedExpectedThumbprint'; Present='$($result.CertificateThumbprintPresent)'; Store='$($result.CertificateStorePath)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.CertificateThumbprintPresent = $false
    $result.CertificateStorePath = 'Error'
    $result.CertificateSubject = 'Error'
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
