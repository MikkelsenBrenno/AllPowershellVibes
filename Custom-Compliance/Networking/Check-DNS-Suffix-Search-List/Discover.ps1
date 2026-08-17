<#
.SYNOPSIS
    Discovers whether the DNS suffix search list contains required suffixes.

.DESCRIPTION
    Intune custom compliance discovery script. The script reads TCP/IP DNS
    suffix configuration from the registry and returns one compressed JSON
    object for custom compliance.

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

$ScriptPackageName = 'Check-DNS-Suffix-Search-List'
$ScriptName = 'Discover'

$RequiredSuffixes = @('contoso.com')
$TcpipParametersPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function ConvertTo-SuffixList {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [array]) {
        return @($Value | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }

    return @(([string]$Value -split ',') | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

# =========================
# MAIN
# =========================

$result = [ordered]@{
    DnsSuffixSearchListCompliant = $false
    RequiredSuffixes = $RequiredSuffixes
    ConfiguredSuffixes = @()
    MissingSuffixes = @()
}

try {
    Initialize-Log
    Write-ScriptMetadata

    $parameters = Get-ItemProperty -LiteralPath $TcpipParametersPath -ErrorAction Stop
    $configuredSuffixes = ConvertTo-SuffixList -Value $parameters.SearchList

    if ($configuredSuffixes.Count -eq 0) {
        $configuredSuffixes = ConvertTo-SuffixList -Value $parameters.Domain
    }

    $normalizedConfigured = @($configuredSuffixes | ForEach-Object { $_.ToLowerInvariant() })
    $missing = @()

    foreach ($suffix in $RequiredSuffixes) {
        if ($normalizedConfigured -notcontains $suffix.ToLowerInvariant()) {
            $missing += $suffix
        }
    }

    $result.ConfiguredSuffixes = $configuredSuffixes
    $result.MissingSuffixes = $missing
    $result.DnsSuffixSearchListCompliant = ($missing.Count -eq 0)

    Write-Log -Message "Discovery completed. Required='$($RequiredSuffixes -join ',')'; Configured='$($configuredSuffixes -join ',')'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.DnsSuffixSearchListCompliant = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
