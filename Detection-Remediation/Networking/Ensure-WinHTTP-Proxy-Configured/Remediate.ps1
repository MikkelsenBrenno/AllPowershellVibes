<#
.SYNOPSIS
    Configures WinHTTP proxy settings.

.DESCRIPTION
    Intune Remediations remediation script. The script can reset WinHTTP proxy
    to direct access or configure a proxy server and bypass list. It starts in
    report-only mode so administrators can validate intended values first.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      WinHTTP proxy configured
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

$ScriptPackageName = 'Ensure-WinHTTP-Proxy-Configured'
$ScriptName = 'Remediate'

$SetDirectAccess = $true
$WinHttpProxyServer = ''
$WinHttpBypassList = ''
$ExpectedWinHttpProxyContains = ''

$ApplyProxy = $false
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

    if (-not (Get-Command -Name netsh.exe -ErrorAction SilentlyContinue)) {
        throw 'netsh.exe is not available on this device.'
    }

    if (-not $ApplyProxy) {
        $message = 'Report-only mode. Set $ApplyProxy to $true after pilot testing to change WinHTTP proxy settings.'
        Write-Log -Message $message -Level 'WARN'
        Write-Output $message

        if ($ExitZeroInReportingOnlyMode) {
            exit 0
        }

        exit 1
    }

    if ($SetDirectAccess) {
        Write-Log -Message 'Resetting WinHTTP proxy to direct access.'
        & netsh.exe winhttp reset proxy | Out-Null
    }
    else {
        if ([string]::IsNullOrWhiteSpace($WinHttpProxyServer)) {
            throw 'WinHttpProxyServer must not be empty when SetDirectAccess is false.'
        }

        Write-Log -Message "Setting WinHTTP proxy. Server='$WinHttpProxyServer'; BypassList='$WinHttpBypassList'."
        & netsh.exe winhttp set proxy "proxy-server=$WinHttpProxyServer" "bypass-list=$WinHttpBypassList" | Out-Null
    }

    $proxyOutput = (@(netsh.exe winhttp show proxy) -join ' ').Trim()
    Write-Log -Message "Post-remediation WinHTTP proxy output: $proxyOutput"

    if ($SetDirectAccess -and $proxyOutput -like '*Direct access*') {
        Write-Output 'Remediation succeeded. WinHTTP proxy is direct access.'
        exit 0
    }

    if (-not [string]::IsNullOrWhiteSpace($ExpectedWinHttpProxyContains) -and $proxyOutput -like "*$ExpectedWinHttpProxyContains*") {
        Write-Output "Remediation succeeded. WinHTTP proxy contains '$ExpectedWinHttpProxyContains'."
        exit 0
    }

    throw 'WinHTTP proxy validation failed after remediation.'
}
catch {
    try { Write-Log -Message "Remediation failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Remediation failed for WinHTTP proxy configuration.'
    exit 1
}
