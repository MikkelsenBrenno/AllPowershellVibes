<#
.SYNOPSIS
    Discovers the Microsoft 365 Apps update channel.

.DESCRIPTION
    Intune custom compliance discovery script. The script reads common
    Microsoft 365 Apps Click-to-Run update channel locations and returns one
    compressed JSON object for Intune custom compliance.

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

$ScriptPackageName = 'Check-Office-Update-Channel'
$ScriptName = 'Discover'

$ExpectedChannelUrl = 'http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60'
$TreatMissingOfficeAsCompliant = $true
$ChannelRegistryChecks = @(
    [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\cloud\office\16.0\Common\officeupdate'; ValueNames = @('UpdatePath', 'UpdateBranch') },
    [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\office\16.0\Common\officeupdate'; ValueNames = @('UpdatePath', 'UpdateBranch') },
    [pscustomobject]@{ Path = 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration'; ValueNames = @('UpdateUrl', 'UpdateChannel', 'CDNBaseUrl') }
)

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

$result = [ordered]@{
    OfficeUpdateChannelCompliant = $false
    DetectedOfficeUpdateChannel = ''
    DetectionSource = ''
}

try {
    Initialize-Log
    Write-ScriptMetadata

    foreach ($check in $ChannelRegistryChecks) {
        $properties = Get-ItemProperty -LiteralPath $check.Path -ErrorAction SilentlyContinue

        if ($null -eq $properties) {
            continue
        }

        foreach ($valueName in $check.ValueNames) {
            $value = $properties.PSObject.Properties[$valueName].Value

            if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
                $result.DetectedOfficeUpdateChannel = [string]$value
                $result.DetectionSource = "$($check.Path)\$valueName"
                break
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($result.DetectedOfficeUpdateChannel)) {
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($result.DetectedOfficeUpdateChannel)) {
        $result.OfficeUpdateChannelCompliant = [bool]$TreatMissingOfficeAsCompliant
        $result.DetectionSource = 'NotFound'
    }
    else {
        $result.OfficeUpdateChannelCompliant = ($result.DetectedOfficeUpdateChannel -eq $ExpectedChannelUrl)
    }

    Write-Log -Message "Discovery completed. Expected='$ExpectedChannelUrl'; Detected='$($result.DetectedOfficeUpdateChannel)'; Source='$($result.DetectionSource)'."
}
catch {
    try { Write-Log -Message "Discovery failed. Returning noncompliant defaults. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    $result.OfficeUpdateChannelCompliant = $false
    $result.DetectedOfficeUpdateChannel = 'Error'
    $result.DetectionSource = 'Error'
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 0
