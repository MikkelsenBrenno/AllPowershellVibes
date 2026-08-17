<#
.SYNOPSIS
    Detects Microsoft Edge startup and homepage policy.

.DESCRIPTION
    Intune Remediations detection script. The script checks configurable Edge
    policy registry values for startup pages and homepage location.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      Edge startup/homepage policy is compliant
    Exit 1:      Edge startup/homepage policy is missing or incorrect

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
$ScriptName = 'Detect'

$EdgePolicyRoot = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$ConfigureStartupUrls = $true
$StartupUrls = @('https://intranet.contoso.com')
$ConfigureHomepage = $true
$HomepageLocation = 'https://intranet.contoso.com'

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

    $issues = New-Object System.Collections.Generic.List[string]
    $policy = Get-ItemProperty -LiteralPath $EdgePolicyRoot -ErrorAction SilentlyContinue

    if ($ConfigureStartupUrls) {
        if ($null -eq $policy -or [int]$policy.RestoreOnStartup -ne 4) {
            $issues.Add('RestoreOnStartup is not 4')
        }

        $urlRoot = Join-Path -Path $EdgePolicyRoot -ChildPath 'RestoreOnStartupURLs'
        $urlPolicy = Get-ItemProperty -LiteralPath $urlRoot -ErrorAction SilentlyContinue

        for ($index = 0; $index -lt $StartupUrls.Count; $index++) {
            $valueName = [string]($index + 1)
            $actualUrl = if ($null -ne $urlPolicy) { $urlPolicy.PSObject.Properties[$valueName].Value } else { $null }
            if ($actualUrl -ne $StartupUrls[$index]) {
                $issues.Add("Startup URL '$valueName' is not '$($StartupUrls[$index])'")
            }
        }
    }

    if ($ConfigureHomepage) {
        if ($null -eq $policy -or [string]$policy.HomepageLocation -ne $HomepageLocation) {
            $issues.Add("HomepageLocation is not '$HomepageLocation'")
        }
    }

    if ($issues.Count -eq 0) {
        Write-Output 'Compliant. Edge startup/homepage policy matches expected settings.'
        exit 0
    }

    Write-Output "Not compliant. $($issues -join '; ')."
    exit 1
}
catch {
    try { Write-Log -Message "Detection failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Not compliant. Edge policy could not be validated.'
    exit 1
}
