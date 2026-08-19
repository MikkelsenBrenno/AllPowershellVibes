<#
.SYNOPSIS
    Detects whether Microsoft Defender antivirus signatures are fresh.

.DESCRIPTION
    Intune Remediations detection script. The script checks Microsoft Defender
    antivirus signature age and exits 0 when signatures are within the
    configured freshness window. It exits 1 when remediation should run.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Defender signatures are fresh
    Exit 1:      Defender signatures are stale or status is unavailable

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
$ScriptPackageName = 'Update-Defender-Signatures'
$ScriptName = 'Detect'

# Maximum acceptable signature age before remediation should run.
$MaximumSignatureAgeDays = 3

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

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. MaximumSignatureAgeDays='$MaximumSignatureAgeDays'."

    if ($MaximumSignatureAgeDays -lt 1) {
        throw 'MaximumSignatureAgeDays must be 1 or greater.'
    }

    if (-not (Get-Command -Name Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
        throw 'Get-MpComputerStatus is not available on this device.'
    }

    $status = Get-MpComputerStatus
    $lastUpdated = $status.AntivirusSignatureLastUpdated

    if ($null -eq $lastUpdated) {
        $message = 'Not compliant. Defender antivirus signature timestamp is unavailable.'
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message
        exit 1
    }

    $signatureAge = New-TimeSpan -Start $lastUpdated -End (Get-Date)
    $signatureAgeDays = [math]::Round($signatureAge.TotalDays, 2)
    Write-Log -Message "AntivirusSignatureLastUpdated='$lastUpdated'; SignatureAgeDays='$signatureAgeDays'."

    if ($signatureAge.TotalDays -ge 0 -and $signatureAge.TotalDays -le $MaximumSignatureAgeDays) {
        $message = "Compliant. Defender signatures are $signatureAgeDays days old."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Not compliant. Defender signatures are $signatureAgeDays days old, maximum is $MaximumSignatureAgeDays days."
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

    Write-Output 'Not compliant. Defender signature freshness could not be validated.'
    exit 1
}
