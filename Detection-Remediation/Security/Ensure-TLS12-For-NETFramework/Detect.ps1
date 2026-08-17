<#
.SYNOPSIS
    Detects whether .NET Framework TLS 1.2 registry values are enabled.

.DESCRIPTION
    Intune Remediations detection script. The script checks .NET Framework
    strong crypto and system default TLS registry values for 64-bit and 32-bit
    .NET Framework paths.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      TLS 1.2 related .NET values are enabled
    Exit 1:      One or more values are missing or different

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

$ScriptPackageName = 'Ensure-TLS12-For-NETFramework'
$ScriptName = 'Detect'

$RegistryTargets = @(
    @{
        Path = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
        Values = @('SchUseStrongCrypto', 'SystemDefaultTlsVersions')
    },
    @{
        Path = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319'
        Values = @('SchUseStrongCrypto', 'SystemDefaultTlsVersions')
    }
)
$ExpectedValue = 1

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

    $nonCompliant = @()

    foreach ($target in $RegistryTargets) {
        if (-not (Test-Path -LiteralPath $target.Path)) {
            $nonCompliant += $target.Path
            continue
        }

        $properties = Get-ItemProperty -LiteralPath $target.Path -ErrorAction Stop
        foreach ($valueName in $target.Values) {
            if ([int]($properties.$valueName) -ne [int]$ExpectedValue) {
                $nonCompliant += "$($target.Path)\$valueName"
            }
        }
    }

    if ($nonCompliant.Count -eq 0) {
        $message = 'Compliant. .NET Framework TLS values are enabled.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Missing or different values: $($nonCompliant -join ', ')."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output '.NET Framework TLS values could not be validated.'
    exit 1
}
