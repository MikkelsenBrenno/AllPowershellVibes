<#
.SYNOPSIS
    Discovers Windows activation status.

.DESCRIPTION
    Intune custom compliance discovery script. The script queries the
    SoftwareLicensingProduct WMI class and returns compressed JSON indicating
    whether Windows is activated.

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

$ScriptPackageName = 'Check-Windows-Activation-Status'
$ScriptName = 'Discover'

$WindowsProductNamePattern = 'Windows*'
$LicensedStatusCode = 1

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
    WindowsActivated = $false
    WindowsLicenseStatus = -1
    WindowsLicenseName = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $products = @(Get-CimInstance -ClassName SoftwareLicensingProduct -ErrorAction Stop |
        Where-Object { $_.Name -like $WindowsProductNamePattern -and -not [string]::IsNullOrWhiteSpace($_.PartialProductKey) } |
        Sort-Object -Property LicenseStatus -Descending)

    $product = $products | Select-Object -First 1

    if ($null -ne $product) {
        $result.WindowsLicenseStatus = [int]$product.LicenseStatus
        $result.WindowsLicenseName = [string]$product.Name
        $result.WindowsActivated = ([int]$product.LicenseStatus -eq $LicensedStatusCode)
    }

    Write-Log -Message "Discovery completed. Product='$($result.WindowsLicenseName)'; LicenseStatus='$($result.WindowsLicenseStatus)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.WindowsActivated = $false
    $result.WindowsLicenseStatus = -1
    $result.WindowsLicenseName = 'Error'
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
