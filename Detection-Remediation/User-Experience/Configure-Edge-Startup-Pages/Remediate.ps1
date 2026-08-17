<#
.SYNOPSIS
    Configures Microsoft Edge startup and homepage policy.

.DESCRIPTION
    Intune Remediations remediation script. The script writes configurable
    Microsoft Edge policy registry values only after ApplyPolicy is enabled.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Edge startup/homepage policy is compliant
    Exit 1:      Edge startup/homepage policy remains noncompliant

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

$ScriptPackageName = 'Configure-Edge-Startup-Pages'
$ScriptName = 'Remediate'

$EdgePolicyRoot = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$ConfigureStartupUrls = $true
$StartupUrls = @('https://intranet.contoso.com')
$ConfigureHomepage = $true
$HomepageLocation = 'https://intranet.contoso.com'
$ApplyPolicy = $false
$ExitZeroInReportingOnlyMode = $false

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

    if (-not $ApplyPolicy) {
        Write-Output 'Edge policy would be configured, but ApplyPolicy is disabled.'
        if ($ExitZeroInReportingOnlyMode) { exit 0 }
        exit 1
    }

    if (-not (Test-Path -LiteralPath $EdgePolicyRoot -PathType Container)) {
        New-Item -Path $EdgePolicyRoot -ItemType Directory -Force | Out-Null
    }

    if ($ConfigureStartupUrls) {
        New-ItemProperty -Path $EdgePolicyRoot -Name 'RestoreOnStartup' -Value 4 -PropertyType DWord -Force | Out-Null
        $urlRoot = Join-Path -Path $EdgePolicyRoot -ChildPath 'RestoreOnStartupURLs'

        if (-not (Test-Path -LiteralPath $urlRoot -PathType Container)) {
            New-Item -Path $urlRoot -ItemType Directory -Force | Out-Null
        }

        $existingUrlPolicy = Get-ItemProperty -LiteralPath $urlRoot -ErrorAction SilentlyContinue
        if ($null -ne $existingUrlPolicy) {
            $existingUrlPolicy.PSObject.Properties |
                Where-Object { $_.Name -match '^\d+$' } |
                ForEach-Object { Remove-ItemProperty -LiteralPath $urlRoot -Name $_.Name -ErrorAction SilentlyContinue }
        }

        for ($index = 0; $index -lt $StartupUrls.Count; $index++) {
            New-ItemProperty -Path $urlRoot -Name ([string]($index + 1)) -Value $StartupUrls[$index] -PropertyType String -Force | Out-Null
        }
    }

    if ($ConfigureHomepage) {
        New-ItemProperty -Path $EdgePolicyRoot -Name 'HomepageLocation' -Value $HomepageLocation -PropertyType String -Force | Out-Null
    }

    Write-Output 'Edge startup/homepage policy configured.'
    exit 0
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed while configuring Edge policy.'
    exit 1
}
