<#
.SYNOPSIS
    Removes unsupported MSI products by product code.

.DESCRIPTION
    Intune Remediations remediation script. The script can uninstall configured
    MSI product codes using msiexec. It reports display-name matches but only
    uninstalls explicit product codes by default for safer customization.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation completed or report-only mode completed
    Exit 1:      Remediation failed

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
$ScriptName = 'Remediate'

$UnsupportedProductCodes = @(
    '{00000000-0000-0000-0000-000000000000}'
)
$MsiExecPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\msiexec.exe'
$MsiExecExtraArguments = @('/qn', '/norestart')
$ApplyUninstall = $false
$AcceptExitCodes = @(0, 3010, 1605)

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
    Write-Log -Message "Remediation started. ApplyUninstall='$ApplyUninstall'; ProductCodes='$($UnsupportedProductCodes -join ',')'."

    if (-not (Test-Path -LiteralPath $MsiExecPath -PathType Leaf)) {
        throw "msiexec.exe was not found at '$MsiExecPath'."
    }

    if (-not $ApplyUninstall) {
        Write-Output "Report-only mode. Would uninstall product codes: $($UnsupportedProductCodes -join ', ')."
        exit 0
    }

    foreach ($productCode in $UnsupportedProductCodes) {
        if ($productCode -eq '{00000000-0000-0000-0000-000000000000}') {
            Write-Log -Message 'Skipping placeholder product code. Customize UnsupportedProductCodes before deployment.' -Level 'WARN'
            continue
        }

        $arguments = @('/x', $productCode) + $MsiExecExtraArguments
        Write-Log -Message "Running msiexec. Arguments='$($arguments -join ' ')'."
        $process = Start-Process -FilePath $MsiExecPath -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden

        if ($AcceptExitCodes -notcontains $process.ExitCode) {
            throw "msiexec failed for '$productCode' with exit code '$($process.ExitCode)'."
        }
    }

    Write-Output 'Remediation completed. Unsupported MSI uninstall commands finished.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed. Unsupported MSI products were not removed.'
    exit 1
}
