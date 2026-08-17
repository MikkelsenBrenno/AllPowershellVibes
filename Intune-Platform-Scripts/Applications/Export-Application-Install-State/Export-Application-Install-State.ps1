<#
.SYNOPSIS
    Exports installation state for configured applications.

.DESCRIPTION
    Intune platform script example. The script searches common machine-wide
    uninstall registry locations for configured display names and writes a JSON
    snapshot for technician troubleshooting.

.NOTES
    Name:        Export-Application-Install-State.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Application state snapshot written
    Exit 1:      Snapshot export failed

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

$ScriptPackageName = 'Export-Application-Install-State'
$ScriptName = 'Export-Application-Install-State'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'ApplicationInstallState.json'
$ApplicationNamePatterns = @('Microsoft 365 Apps', 'Microsoft Edge', 'Company Portal')
$UninstallRegistryPaths = @(
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

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Test-Path -LiteralPath $InventoryRoot -PathType Container)) {
        New-Item -Path $InventoryRoot -ItemType Directory -Force | Out-Null
    }

    $installedApps = foreach ($path in $UninstallRegistryPaths) {
        if (Test-Path -LiteralPath $path) {
            Get-ChildItem -LiteralPath $path -ErrorAction SilentlyContinue | ForEach-Object {
                $app = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
                if (-not [string]::IsNullOrWhiteSpace($app.DisplayName)) {
                    [pscustomobject]@{
                        DisplayName = [string]$app.DisplayName
                        DisplayVersion = [string]$app.DisplayVersion
                        Publisher = [string]$app.Publisher
                        InstallDate = [string]$app.InstallDate
                        RegistryKey = [string]$_.PSChildName
                    }
                }
            }
        }
    }

    $applicationResults = foreach ($pattern in $ApplicationNamePatterns) {
        $matches = @($installedApps | Where-Object { $_.DisplayName -like "*$pattern*" })
        [ordered]@{
            Pattern = $pattern
            Installed = ($matches.Count -gt 0)
            MatchCount = $matches.Count
            Matches = @($matches)
        }
    }

    $snapshot = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        ApplicationNamePatterns = @($ApplicationNamePatterns)
        Results = @($applicationResults)
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    Write-Output "Application install state written to '$inventoryPath'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export application install state.'
    exit 1
}
