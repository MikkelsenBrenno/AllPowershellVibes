<#
.SYNOPSIS
    Detects whether WinHTTP proxy is direct access.

.DESCRIPTION
    Intune Remediations detection script. The script reads netsh winhttp proxy output and exits 1 when it does not match configured direct access indicators.

.NOTES
    Name:        Detect.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      WinHTTP proxy is direct access
    Exit 1:      WinHTTP proxy is not direct access

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
$ScriptPackageName = 'Reset-WinHTTP-Proxy-To-Direct'
$ScriptName = 'Detect'

$DirectAccessIndicators = @('Direct access', 'no proxy server')

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

function Get-WinHttpProxyText {
    if (-not (Get-Command -Name netsh.exe -ErrorAction SilentlyContinue)) {
        throw 'netsh.exe is not available on this device.'
    }

    return (@(& netsh.exe winhttp show proxy 2>&1) -join ' ').Trim()
}

function Test-WinHttpDirectAccess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProxyText
    )

    foreach ($indicator in $DirectAccessIndicators) {
        if ($ProxyText -like "*$indicator*") {
            return $true
        }
    }

    return $false
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Detection started. Expected direct access indicators='$($DirectAccessIndicators -join ',')'."

    $proxyText = Get-WinHttpProxyText
    Write-Log -Message "Current WinHTTP proxy output: $proxyText"

    if (Test-WinHttpDirectAccess -ProxyText $proxyText) {
        $message = 'Compliant. WinHTTP proxy is configured for direct access.'
        Write-Log -Message $message
        Write-Output $message
        exit 0
    }

    $message = 'Not compliant. WinHTTP proxy is not configured for direct access.'
    Write-Log -Message $message -Level 'WARN'
    Write-Output $message
    exit 1
}
catch {
    try {
        Write-Log -Message "$ScriptName failed. $($_.Exception.Message)" -Level 'ERROR'
    }
    catch {
    }

    Write-Output 'Not compliant. WinHTTP proxy could not be validated.'
    exit 1
}

