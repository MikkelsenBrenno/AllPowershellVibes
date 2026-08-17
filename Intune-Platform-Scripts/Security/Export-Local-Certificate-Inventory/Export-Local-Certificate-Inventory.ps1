<#
.SYNOPSIS
    Exports local machine certificate inventory to a JSON file.

.DESCRIPTION
    Intune platform script. The script inventories configured certificate
    stores and marks certificates that are already expired or expiring soon.

.NOTES
    Name:        Export-Local-Certificate-Inventory.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Platform Script
    Exit 0:      Inventory exported
    Exit 1:      Inventory export failed

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

$ScriptPackageName = 'Export-Local-Certificate-Inventory'
$ScriptName = 'Export-Local-Certificate-Inventory'

$CertificateStorePaths = @(
    'Cert:\LocalMachine\My',
    'Cert:\LocalMachine\Root',
    'Cert:\LocalMachine\CA'
)
$ExpiringWithinDays = 60
$OutputRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$OutputFileName = 'LocalCertificateInventory.json'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null }; if (-not (Test-Path -LiteralPath $OutputRoot)) { New-Item -Path $OutputRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $now = Get-Date
    $expiringBefore = $now.AddDays($ExpiringWithinDays)
    $certificates = @()

    foreach ($storePath in $CertificateStorePaths) {
        if (-not (Test-Path -LiteralPath $storePath)) {
            Write-Log -Message "Certificate store '$storePath' was not found." -Level 'WARN'
            continue
        }

        $certificates += Get-ChildItem -LiteralPath $storePath -ErrorAction SilentlyContinue | ForEach-Object {
            [pscustomobject]@{
                StorePath = $storePath
                Subject = $_.Subject
                Issuer = $_.Issuer
                Thumbprint = $_.Thumbprint
                FriendlyName = $_.FriendlyName
                NotBefore = $_.NotBefore.ToString('o')
                NotAfter = $_.NotAfter.ToString('o')
                HasPrivateKey = $_.HasPrivateKey
                IsExpired = ($_.NotAfter -lt $now)
                ExpiresWithinDays = ($_.NotAfter -le $expiringBefore)
            }
        }
    }

    $outputPath = Join-Path -Path $OutputRoot -ChildPath $OutputFileName
    $payload = [ordered]@{
        ComputerName = $env:COMPUTERNAME
        CapturedAt = $now.ToString('o')
        ExpiringWithinDays = $ExpiringWithinDays
        CertificateCount = $certificates.Count
        Certificates = $certificates
    }

    $payload | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outputPath -Encoding UTF8
    Write-Log -Message "Certificate inventory exported. Path='$outputPath'; Count='$($certificates.Count)'."
    Write-Output "Certificate inventory exported to '$outputPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Certificate inventory export failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Certificate inventory export failed.'
    exit 1
}
