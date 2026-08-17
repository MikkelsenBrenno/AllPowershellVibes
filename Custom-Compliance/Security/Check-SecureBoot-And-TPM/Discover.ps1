<#
.SYNOPSIS
    Discovers Secure Boot and TPM readiness.

.DESCRIPTION
    Intune custom compliance discovery script. The script reports whether
    Secure Boot is enabled and TPM is present, enabled, activated, and owned.

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

$ScriptPackageName = 'Check-SecureBoot-And-TPM'
$ScriptName = 'Discover'

$RequireSecureBoot = $true
$RequireTpmReady = $true

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log {
    param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO')
    Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8
}
function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

# =========================
# MAIN
# =========================

$result = [ordered]@{
    SecureBootEnabled = $false
    TpmReady = $false
    TpmPresent = $false
    TpmEnabled = $false
    TpmActivated = $false
    TpmOwned = $false
    HardwareSecurityCompliant = $false
}

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Discovery started. RequireSecureBoot='$RequireSecureBoot'; RequireTpmReady='$RequireTpmReady'."

    try {
        $result.SecureBootEnabled = [bool](Confirm-SecureBootUEFI -ErrorAction Stop)
    }
    catch {
        Write-Log -Message "Secure Boot check failed or is unsupported. $($_.Exception.Message)" -Level 'WARN'
        $result.SecureBootEnabled = $false
    }

    if (Get-Command -Name Get-Tpm -ErrorAction SilentlyContinue) {
        $tpm = Get-Tpm -ErrorAction Stop
        $result.TpmPresent = [bool]$tpm.TpmPresent
        $result.TpmEnabled = [bool]$tpm.TpmEnabled
        $result.TpmActivated = [bool]$tpm.TpmActivated
        $result.TpmOwned = [bool]$tpm.TpmOwned
        $result.TpmReady = ($result.TpmPresent -and $result.TpmEnabled -and $result.TpmActivated -and $result.TpmOwned)
    }
    else {
        Write-Log -Message 'Get-Tpm is not available on this device.' -Level 'WARN'
    }

    $secureBootOk = (-not $RequireSecureBoot -or $result.SecureBootEnabled)
    $tpmOk = (-not $RequireTpmReady -or $result.TpmReady)
    $result.HardwareSecurityCompliant = ($secureBootOk -and $tpmOk)
    Write-Log -Message "Discovery completed. SecureBootEnabled='$($result.SecureBootEnabled)'; TpmReady='$($result.TpmReady)'; Compliant='$($result.HardwareSecurityCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.HardwareSecurityCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
