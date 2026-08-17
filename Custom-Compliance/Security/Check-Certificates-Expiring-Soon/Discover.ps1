<#
.SYNOPSIS
    Discovers certificates that expire soon.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks a
    configurable certificate store and returns one compressed JSON object
    indicating whether any matching certificates expire within the configured
    number of days.

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

$ScriptPackageName = 'Check-Certificates-Expiring-Soon'
$ScriptName = 'Discover'

$CertificateStorePath = 'Cert:\LocalMachine\My'
$ExpireWithinDays = 30
$SubjectPattern = '*'
$IncludeExpiredCertificates = $true

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
    NoCertificatesExpiringSoon = $false
    ExpiringCertificateCount = 0
    EarliestExpirationDate = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $now = Get-Date
    $cutoff = $now.AddDays($ExpireWithinDays)
    $certificates = @(
        Get-ChildItem -LiteralPath $CertificateStorePath -ErrorAction Stop |
            Where-Object {
                $_.Subject -like $SubjectPattern -and
                $_.NotAfter -le $cutoff -and
                ($IncludeExpiredCertificates -or $_.NotAfter -ge $now)
            }
    )

    $earliestCertificate = $certificates | Sort-Object -Property NotAfter | Select-Object -First 1

    $result.ExpiringCertificateCount = $certificates.Count
    $result.NoCertificatesExpiringSoon = ($certificates.Count -eq 0)

    if ($null -ne $earliestCertificate) {
        $result.EarliestExpirationDate = $earliestCertificate.NotAfter.ToString('yyyy-MM-dd')
    }

    Write-Log -Message "Discovery completed. Store='$CertificateStorePath'; ExpireWithinDays='$ExpireWithinDays'; SubjectPattern='$SubjectPattern'; Count='$($certificates.Count)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.NoCertificatesExpiringSoon = $false
    $result.ExpiringCertificateCount = -1
    $result.EarliestExpirationDate = 'Error'
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
