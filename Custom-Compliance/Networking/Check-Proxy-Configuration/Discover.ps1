<#
.SYNOPSIS
    Discovers WinHTTP and user proxy configuration.

.DESCRIPTION
    Intune custom compliance discovery script. The script checks configurable
    WinHTTP and Internet Settings proxy values and returns one compressed JSON
    object.

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

$ScriptPackageName = 'Check-Proxy-Configuration'
$ScriptName = 'Discover'

# Choose Enabled, Disabled, or Any for the user proxy toggle.
$ExpectedUserProxyState = 'Any'
$ExpectedProxyServerContains = ''
$ExpectedAutoConfigUrlContains = ''
$CheckWinHttpProxy = $true
$ExpectedWinHttpProxyContains = ''

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Test-ContainsRequirement {
    param(
        [string]$ActualValue,
        [string]$ExpectedContains
    )

    if ([string]::IsNullOrWhiteSpace($ExpectedContains)) {
        return $true
    }

    return ($ActualValue -like "*$ExpectedContains*")
}

# =========================
# MAIN
# =========================

$result = [ordered]@{
    ProxyConfigurationCompliant = $false
    UserProxyEnabled = $false
    ProxyServer = ''
    AutoConfigUrl = ''
    WinHttpProxy = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata

    if ($ExpectedUserProxyState -notin @('Enabled', 'Disabled', 'Any')) {
        throw "ExpectedUserProxyState '$ExpectedUserProxyState' is not valid."
    }

    $internetSettingsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    $internetSettings = Get-ItemProperty -LiteralPath $internetSettingsPath -ErrorAction SilentlyContinue

    if ($null -ne $internetSettings) {
        $result.UserProxyEnabled = ([int]($internetSettings.ProxyEnable) -eq 1)
        $result.ProxyServer = [string]$internetSettings.ProxyServer
        $result.AutoConfigUrl = [string]$internetSettings.AutoConfigURL
    }

    if ($CheckWinHttpProxy -and (Get-Command -Name netsh.exe -ErrorAction SilentlyContinue)) {
        $winHttpOutput = @(netsh.exe winhttp show proxy) -join ' '
        $result.WinHttpProxy = $winHttpOutput.Trim()
    }

    $userProxyStateCompliant = (
        $ExpectedUserProxyState -eq 'Any' -or
        ($ExpectedUserProxyState -eq 'Enabled' -and $result.UserProxyEnabled) -or
        ($ExpectedUserProxyState -eq 'Disabled' -and -not $result.UserProxyEnabled)
    )

    $proxyServerCompliant = Test-ContainsRequirement -ActualValue $result.ProxyServer -ExpectedContains $ExpectedProxyServerContains
    $autoConfigCompliant = Test-ContainsRequirement -ActualValue $result.AutoConfigUrl -ExpectedContains $ExpectedAutoConfigUrlContains
    $winHttpCompliant = (-not $CheckWinHttpProxy -or (Test-ContainsRequirement -ActualValue $result.WinHttpProxy -ExpectedContains $ExpectedWinHttpProxyContains))

    $result.ProxyConfigurationCompliant = ($userProxyStateCompliant -and $proxyServerCompliant -and $autoConfigCompliant -and $winHttpCompliant)

    Write-Log -Message "Discovery completed. UserProxyEnabled='$($result.UserProxyEnabled)'; ProxyServer='$($result.ProxyServer)'; AutoConfigUrl='$($result.AutoConfigUrl)'; Compliant='$($result.ProxyConfigurationCompliant)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.ProxyConfigurationCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
