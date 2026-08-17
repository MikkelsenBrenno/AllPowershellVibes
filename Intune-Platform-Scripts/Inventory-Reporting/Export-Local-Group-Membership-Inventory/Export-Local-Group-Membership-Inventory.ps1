<#
.SYNOPSIS
    Exports local group membership inventory.

.DESCRIPTION
    Intune platform script example. The script collects local groups and group
    members, then writes a JSON inventory file to a configurable local path for
    technician troubleshooting.

.NOTES
    Name:        Export-Local-Group-Membership-Inventory.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Intune-Platform-Scripts
    Exit 0:      Local group membership inventory written
    Exit 1:      Local group membership inventory failed

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

$ScriptPackageName = 'Export-Local-Group-Membership-Inventory'
$ScriptName = 'Export-Local-Group-Membership-Inventory'

$InventoryRoot = Join-Path -Path $env:ProgramData -ChildPath 'IntuneScriptLibrary\Inventory'
$InventoryFileName = 'LocalGroupMembershipInventory.json'
$IncludeEmptyGroups = $true
$GroupNameAllowList = @()
$GroupNameDenyList = @()

# =========================
# LOGGING
# =========================

$BaseLogRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\Logs'
$LogRoot = Join-Path -Path $BaseLogRoot -ChildPath $ScriptPackageName
$LogPath = Join-Path -Path $LogRoot -ChildPath "$ScriptName.log"

function Initialize-Log { if (-not (Test-Path -LiteralPath $LogRoot)) { New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null } }
function Write-Log { param([Parameter(Mandatory = $true)][string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'); Add-Content -Path $LogPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Level] $Message" -Encoding UTF8 }
function Write-ScriptMetadata { $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name; Write-Log -Message "Script metadata: Package='$ScriptPackageName'; Script='$ScriptName'; LogPath='$LogPath'; User='$identity'; PowerShell='$($PSVersionTable.PSVersion)'; Is64BitProcess='$([System.Environment]::Is64BitProcess)'." }

function Test-GroupIncluded {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupName
    )

    if ($GroupNameAllowList.Count -gt 0 -and $GroupNameAllowList -notcontains $GroupName) {
        return $false
    }

    if ($GroupNameDenyList -contains $GroupName) {
        return $false
    }

    return $true
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata

    if (-not (Get-Command -Name Get-LocalGroup -ErrorAction SilentlyContinue)) {
        throw 'Get-LocalGroup is not available.'
    }

    if (-not (Get-Command -Name Get-LocalGroupMember -ErrorAction SilentlyContinue)) {
        throw 'Get-LocalGroupMember is not available.'
    }

    if (-not (Test-Path -LiteralPath $InventoryRoot -PathType Container)) {
        New-Item -Path $InventoryRoot -ItemType Directory -Force | Out-Null
    }

    $groups = @(Get-LocalGroup -ErrorAction Stop | Where-Object { Test-GroupIncluded -GroupName $_.Name } | Sort-Object -Property Name)
    $groupInventory = foreach ($group in $groups) {
        $memberQuerySucceeded = $true
        $memberQueryError = ''
        $members = @()

        try {
            $members = @(Get-LocalGroupMember -Group $group.Name -ErrorAction Stop |
                Sort-Object -Property Name |
                ForEach-Object {
                    [PSCustomObject]@{
                        Name = [string]$_.Name
                        ObjectClass = [string]$_.ObjectClass
                        PrincipalSource = [string]$_.PrincipalSource
                        SID = [string]$_.SID
                    }
                })
        }
        catch {
            $memberQuerySucceeded = $false
            $memberQueryError = $_.Exception.Message
            Write-Log -Message "Could not enumerate members for group '$($group.Name)'. $memberQueryError" -Level 'WARN'
        }

        if (-not $IncludeEmptyGroups -and $members.Count -eq 0) {
            continue
        }

        [PSCustomObject]@{
            GroupName = [string]$group.Name
            Description = [string]$group.Description
            SID = [string]$group.SID
            MemberCount = $members.Count
            MemberQuerySucceeded = [bool]$memberQuerySucceeded
            MemberQueryError = $memberQueryError
            Members = $members
        }
    }

    $inventory = [ordered]@{
        CapturedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        ComputerName = $env:COMPUTERNAME
        GroupCount = @($groupInventory).Count
        IncludeEmptyGroups = [bool]$IncludeEmptyGroups
        Groups = @($groupInventory)
    }

    $inventoryPath = Join-Path -Path $InventoryRoot -ChildPath $InventoryFileName
    $inventory | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $inventoryPath -Encoding UTF8

    if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) {
        throw "Local group membership inventory '$inventoryPath' was not created."
    }

    Write-Log -Message "Local group membership inventory written. Path='$inventoryPath'; GroupCount='$($inventory.GroupCount)'."
    Write-Output "Local group membership inventory written to '$inventoryPath'. GroupCount='$($inventory.GroupCount)'."
    exit 0
}
catch {
    try { Write-Log -Message "Script failed. $($_.Exception.Message)" -Level 'ERROR' } catch {}
    Write-Output 'Failed to export local group membership inventory.'
    exit 1
}
