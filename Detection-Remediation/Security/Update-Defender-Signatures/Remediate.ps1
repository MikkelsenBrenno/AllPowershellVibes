<#
.SYNOPSIS
    Updates Microsoft Defender antivirus signatures.

.DESCRIPTION
    Intune Remediations remediation script. The script can run
    Update-MpSignature and validate that Microsoft Defender antivirus
    signatures are within the configured freshness window. It starts in
    report-only mode so administrators can confirm update source behavior.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Remediation succeeded
    Exit 1:      Remediation failed or report-only mode is enabled

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
$ScriptName = 'Remediate'

# Maximum acceptable signature age after remediation.
$MaximumSignatureAgeDays = 3

# Leave empty to use the device's configured source order.
# Examples: MicrosoftUpdateServer, MMPC, InternalDefinitionUpdateServer, FileShares.
$UpdateSource = ''

# Keep report-only mode enabled until the update path is approved for your tenant.
$ApplyUpdate = $false
$ExitZeroInReportingOnlyMode = $false

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

function Test-SignatureFreshness {
    param(
        [Parameter(Mandatory = $true)]
        [int]$MaximumAgeDays
    )

    $status = Get-MpComputerStatus
    $lastUpdated = $status.AntivirusSignatureLastUpdated

    if ($null -eq $lastUpdated) {
        return [pscustomobject]@{
            IsFresh          = $false
            LastUpdated      = $null
            SignatureAgeDays = $null
        }
    }

    $signatureAge = New-TimeSpan -Start $lastUpdated -End (Get-Date)

    return [pscustomobject]@{
        IsFresh          = ($signatureAge.TotalDays -le $MaximumAgeDays)
        LastUpdated      = $lastUpdated
        SignatureAgeDays = [math]::Round($signatureAge.TotalDays, 2)
    }
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. MaximumSignatureAgeDays='$MaximumSignatureAgeDays'; UpdateSource='$UpdateSource'; ApplyUpdate='$ApplyUpdate'."

    if ($MaximumSignatureAgeDays -lt 1) {
        throw 'MaximumSignatureAgeDays must be 1 or greater.'
    }

    if (-not (Get-Command -Name Get-MpComputerStatus -ErrorAction SilentlyContinue)) {
        throw 'Get-MpComputerStatus is not available on this device.'
    }

    if (-not (Get-Command -Name Update-MpSignature -ErrorAction SilentlyContinue)) {
        throw 'Update-MpSignature is not available on this device.'
    }

    $before = Test-SignatureFreshness -MaximumAgeDays $MaximumSignatureAgeDays
    Write-Log -Message "Before remediation: LastUpdated='$($before.LastUpdated)'; SignatureAgeDays='$($before.SignatureAgeDays)'; IsFresh='$($before.IsFresh)'."

    if (-not $ApplyUpdate) {
        $message = 'Report-only mode. Set $ApplyUpdate to $true after pilot testing to run Update-MpSignature.'
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message

        if ($ExitZeroInReportingOnlyMode) {
            exit 0
        }

        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($UpdateSource)) {
        Write-Log -Message 'Running Update-MpSignature with the device configured update source order.'
        Update-MpSignature
    }
    else {
        Write-Log -Message "Running Update-MpSignature with UpdateSource='$UpdateSource'."
        Update-MpSignature -UpdateSource $UpdateSource
    }

    $after = Test-SignatureFreshness -MaximumAgeDays $MaximumSignatureAgeDays
    Write-Log -Message "After remediation: LastUpdated='$($after.LastUpdated)'; SignatureAgeDays='$($after.SignatureAgeDays)'; IsFresh='$($after.IsFresh)'."

    if ($after.IsFresh) {
        $message = "Remediation succeeded. Defender signatures are $($after.SignatureAgeDays) days old."
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = "Remediation failed. Defender signatures are still stale. LastUpdated='$($after.LastUpdated)'; SignatureAgeDays='$($after.SignatureAgeDays)'."
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

    Write-Output 'Remediation failed for Defender signatures.'
    exit 1
}
