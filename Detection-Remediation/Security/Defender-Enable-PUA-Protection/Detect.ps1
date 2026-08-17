<#
.SYNOPSIS
    Detects whether Microsoft Defender PUA protection is enabled.

.DESCRIPTION
    Intune Remediations detection script. The script checks the Microsoft
    Defender Antivirus PUAProtection preference and exits 0 when it matches
    the configured desired state. It exits 1 when remediation should run.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      PUA protection is compliant
    Exit 1:      PUA protection is missing, different, or unavailable

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
$ScriptName = 'Detect'

# Choose one of: Enabled, Disabled, AuditMode.
# Recommended security state is Enabled.
$DesiredPUAProtection = 'Enabled'

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
    Write-Log -Message "Detection started. DesiredPUAProtection='$DesiredPUAProtection'."

    if ($DesiredPUAProtection -notin @('Enabled', 'Disabled', 'AuditMode')) {
        throw "DesiredPUAProtection '$DesiredPUAProtection' is not valid."
    }

    if (-not (Get-Command -Name Get-MpPreference -ErrorAction SilentlyContinue)) {
        throw 'Get-MpPreference is not available on this device.'
    }

    $preferences = Get-MpPreference
    $currentValue = Convert-DefenderPreferenceValue -Value $preferences.PUAProtection

    if ($currentValue -eq $DesiredPUAProtection) {
        $message = "Compliant. Defender PUA protection is '$currentValue'."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Defender PUA protection is '$currentValue'. Expected '$DesiredPUAProtection'."
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Not compliant. Defender PUA protection could not be validated.'
    exit 1
}

