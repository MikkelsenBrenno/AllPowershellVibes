<#
.SYNOPSIS
    Enables Microsoft Defender PUA protection.

.DESCRIPTION
    Intune Remediations remediation script. The script sets the Microsoft
    Defender Antivirus PUAProtection preference to the configured desired
    state and validates the final state.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation succeeded
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

# Keep these names aligned with the folder and script file.
# Logs are written to Logs\<ScriptPackageName>\<ScriptName>.log.
$ScriptPackageName = 'Defender-Enable-PUA-Protection'
$ScriptName = 'Remediate'

# Choose one of: Enabled, Disabled, AuditMode.
# Recommended security state is Enabled.
$DesiredPUAProtection = 'Enabled'

# Increase this if policy or platform state needs more time before validation.
$ValidationDelaySeconds = 3

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log {
    if (-not (Test-Path -LiteralPath $LogRoot)) {
        New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "$timestamp [$Level] $Message"
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Write-ScriptMetadata {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'."
}

function Convert-DefenderPreferenceValue {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Value
    )

    if ($null -eq $Value) {
        return 'Unknown'
    }

    $valueText = $Value.ToString()
    $valueMap = @{
        '0' = 'Disabled'
        '1' = 'Enabled'
        '2' = 'AuditMode'
    }

    if ($valueMap.ContainsKey($valueText)) {
        return $valueMap[$valueText]
    }

    return $valueText
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. DesiredPUAProtection='$DesiredPUAProtection'."

    if ($DesiredPUAProtection -notin @('Enabled', 'Disabled', 'AuditMode')) {
        throw "DesiredPUAProtection '$DesiredPUAProtection' is not valid."
    }

    if (-not (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue)) {
        throw 'Get-MpPreference is not available on this device.'
    }

    if (-not (Get-Command -Name Set-MpPreference -ErrorAction SilentlyContinue)) {
        throw 'Set-MpPreference is not available on this device.'
    }

    $before = Convert-DefenderPreferenceValue -Value (Get-MpPreference).PUAProtection
    Write-Log -Message "Current Defender PUA protection value is '$before'."

    if ($before -ne $DesiredPUAProtection) {
        Write-Log -Message "Setting Defender PUA protection to '$DesiredPUAProtection'."
        Set-MpPreference -PUAProtection $DesiredPUAProtection
    }

    Start-Sleep -Seconds $ValidationDelaySeconds

    $after = Convert-DefenderPreferenceValue -Value (Get-MpPreference).PUAProtection

    if ($after -eq $DesiredPUAProtection) {
        $message = "Remediation succeeded. Defender PUA protection is '$after'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. Defender PUA protection is '$after'. Expected '$DesiredPUAProtection'."
    Write-Log -Message $message -Level 'ERROR'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Remediation failed for Defender PUA protection.'
    exit 1
}

