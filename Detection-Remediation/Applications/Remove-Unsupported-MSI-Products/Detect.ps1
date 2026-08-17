<#
.SYNOPSIS
    Detects unsupported MSI products by product code or display name.

.DESCRIPTION
    Intune Remediations detection script. The script inventories uninstall
    registry keys and reports noncompliance when configured product codes or
    display name patterns are found.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Unsupported MSI products were not found
    Exit 1:      One or more unsupported products were found

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

$ScriptPackageName = 'Remove-Unsupported-MSI-Products'
$ScriptName = 'Detect'

$UnsupportedProductCodes = @(
    '{00000000-0000-0000-0000-000000000000}'
)
$UnsupportedDisplayNamePatterns = @(
    'Example Unsupported App*'
)
$UninstallRegistryRoots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
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

function Get-InstalledProduct {
    foreach ($root in $UninstallRegistryRoots) {
        if (-not (Test-Path -LiteralPath $root)) {
            continue
        }

        Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue | ForEach-Object {
            $item = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            [pscustomobject]@{
                ProductCode = $_.PSChildName
                DisplayName = [string]$item.DisplayName
                DisplayVersion = [string]$item.DisplayVersion
                Publisher = [string]$item.Publisher
                RegistryPath = $_.PSPath
            }
        }
    }
}

function Test-UnsupportedName {
    param([string]$DisplayName)

    foreach ($pattern in $UnsupportedDisplayNamePatterns) {
        if ($DisplayName -like $pattern) {
            return $true
        }
    }

    return $false
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    $installedProducts = @(Get-InstalledProduct | Where-Object { -not [string]::IsNullOrWhiteSpace($_.DisplayName) })
    $matches = @($installedProducts | Where-Object { ($UnsupportedProductCodes -contains $_.ProductCode) -or (Test-UnsupportedName -DisplayName $_.DisplayName) })

    if ($matches.Count -eq 0) {
        $message = 'Compliant. Unsupported MSI products were not found.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $matchSummary = @($matches | ForEach-Object { "$($_.DisplayName) $($_.DisplayVersion) [$($_.ProductCode)]" })
    $message = "Not compliant. Unsupported products found: $($matchSummary -join '; ')."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Unsupported MSI products could not be validated.'
    exit 1
}
