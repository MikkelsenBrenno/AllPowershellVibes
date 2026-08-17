<#
.SYNOPSIS
    Exports Windows update history summary.

.DESCRIPTION
    Intune platform script example. The script collects installed hotfix
    information and optional recent Windows Update Client events, then writes
    a JSON summary to a local troubleshooting folder.

.NOTES
    Name:        Export-Windows-Update-History-Summary.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Windows update history summary written
    Exit 1:      Windows update history summary failed

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

$ScriptPackageName = 'Export-Windows-Update-History-Summary'
$ScriptName = 'Export-Windows-Update-History-Summary'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'WindowsUpdateHistorySummary.json'
$IncludeWindowsUpdateClientEvents = $true
$EventLookBackDays = 14
$MaxUpdateEvents = 100
$WindowsUpdateClientProviderName = 'Microsoft-Windows-WindowsUpdateClient'
$WindowsUpdateClientEventIds = @(19, 20, 25, 31, 34, 43, 44)
$MaxMessageLength = 500

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function ConvertTo-ShortMessage {
    param(
        [AllowNull()]
        [string]$Message
    )

    if ([string]::IsNullOrWhiteSpace($Message)) {
        return ''
    }

    $singleLine = ($Message -replace '\s+', ' ').Trim()
    if ($singleLine.Length -le $MaxMessageLength) {
        return $singleLine
    }

    return $singleLine.Substring(0, $MaxMessageLength)
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Test-Path -LiteralPath $InventoryRoot -PathType Container)) {
        New-Item -Path $InventoryRoot -ItemType Directory -Force | Out-Null
    }

    $hotfixes = @(Get-HotFix -ErrorAction SilentlyContinue |
        Sort-Object -Property InstalledOn -Descending |
        ForEach-Object {
            [PSCustomObject]@{
                HotFixId = [string]$_.HotFixID
                Description = [string]$_.Description
                InstalledBy = [string]$_.InstalledBy
                InstalledOn = if ($null -ne $_.InstalledOn) { ([datetime]$_.InstalledOn).ToString('yyyy-MM-dd') } else { '' }
                Caption = [string]$_.Caption
            }
        })

    $updateEvents = @()
    $eventQuerySucceeded = $false
    $eventQueryError = ''

    if ($IncludeWindowsUpdateClientEvents) {
        try {
            $filter = @{
                ProviderName = $WindowsUpdateClientProviderName
                StartTime = (Get-Date).AddDays(-[math]::Abs($EventLookBackDays))
                Id = $WindowsUpdateClientEventIds
            }

            $updateEvents = @(Get-WinEvent -FilterHashtable $filter -MaxEvents $MaxUpdateEvents -ErrorAction Stop |
                ForEach-Object {
                    [PSCustomObject]@{
                        TimeCreated = if ($null -ne $_.TimeCreated) { $_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
                        Id = [int]$_.Id
                        ProviderName = [string]$_.ProviderName
                        LevelDisplayName = [string]$_.LevelDisplayName
                        Message = ConvertTo-ShortMessage -Message $_.Message
                    }
                })

            $eventQuerySucceeded = $true
        }
        catch {
            $eventQueryError = $_.Exception.Message
            Write-Log -Message "Windows Update Client event query failed. $eventQueryError" -Level 'WARN'
        }
    }

    $inventory = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        HotFixCount = $hotfixes.Count
        HotFixes = $hotfixes
        IncludeWindowsUpdateClientEvents = [bool]$IncludeWindowsUpdateClientEvents
        EventLookBackDays = [int]$EventLookBackDays
        EventQuerySucceeded = [bool]$eventQuerySucceeded
        EventQueryError = $eventQueryError
        UpdateEventCount = $updateEvents.Count
        UpdateEvents = @($updateEvents | Sort-Object -Property TimeCreated -Descending)
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $inventory | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) {
        throw "Windows update history summary '$inventoryPath' was not created."
    }

    Write-Log -Message "Windows update history summary written. Path='$inventoryPath'; HotFixCount='$($hotfixes.Count)'; UpdateEventCount='$($updateEvents.Count)'."
    Write-Output "Windows update history summary written to '$inventoryPath'. HotFixCount='$($hotfixes.Count)'; UpdateEventCount='$($updateEvents.Count)'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export Windows update history summary.'
    exit 1
}
