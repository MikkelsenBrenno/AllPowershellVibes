<#
.SYNOPSIS
    Records and optionally alerts on disk predictive failure signals.

.DESCRIPTION
    Intune Remediations remediation script. Predictive disk failure is a
    hardware replacement or backup/escalation scenario, not something that
    should be automatically repaired by PowerShell. This script rechecks the
    disk that contains the Windows installation, writes detailed logs, and can
    optionally send a Teams alert.

.NOTES
    Name:        Remediate.ps1
    Version:     1.0.0
    PowerShell:  Windows PowerShell 5.1
    Context:     System recommended

.INTUNE
    Workload:    Detection and Remediation
    Exit 0:      No predictive disk failure detected, or reporting-only mode is enabled
    Exit 1:      Predictive disk failure remains and needs manual action

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
$ScriptPackageName = 'Disk-Detect-Predictive-Failure'
$ScriptName = 'Remediate'

# Uses MSStorageDriver_FailurePredictStatus from root\wmi.
# Leave enabled unless your hardware vendor provides a better source.
$CheckSmartPredictiveFailure = $true

# Target only the drive where Windows is installed. The default resolves from
# $env:SystemDrive, which is normally C:.
$TargetDriveLetter = ($env:SystemDrive -replace ':', '')

# Uses Win32_DiskDrive and Get-Disk as fallback health sources for the OS disk.
# This helps on devices where SMART predictive data is limited or unavailable.
$CheckDiskHealthFallback = $true

# Disk health states that should be treated as noncompliant.
$UnhealthyDiskHealthStatuses = @('Warning', 'Unhealthy')

# Disk operational states that should be treated as noncompliant.
$UnhealthyDiskOperationalStatuses = @('Predictive Failure')

# Win32_DiskDrive status values that should be treated as noncompliant.
$UnhealthyWin32DiskStatuses = @('Pred Fail', 'Error', 'Degraded')

# Keep this $true when you want Intune to keep showing remediation failure
# until the hardware issue is resolved. Set to $false for reporting-only mode.
$ExitOneWhenPredictiveFailureRemains = $true

# =========================
# OPTIONAL TEAMS FAILURE ALERTING
# =========================

# Set to $true in the deployed copy when Teams alerting should be active.
# When this is $false, Send-TeamsFailureAlert silently returns and the script continues.
$EnableTeamsFailureAlert = $false

# Treat this URL as a secret. Do not commit a real webhook URL to GitHub.
# Admins should set this in their deployed/customized copy of the script.
$TeamsWebhookUrl = ''

# Card and routing values for this script.
$TeamsAlertName = $ScriptPackageName
$TeamsAlertTitle = 'Disk Predictive Failure Detected'
$TeamsAlertSource = 'Microsoft Intune Remediation'
$TeamsAlertFlowTriggerTag = 'INTUNE_DISK_PREDICTIVE_FAILURE'

# Keep details compact enough for Teams cards and readable channel messages.
$TeamsAlertMaxDetailCharacters = 5000

# Include the last lines of the script log in the Teams alert when available.
$TeamsAlertIncludeLogTail = $true
$TeamsAlertLogTailLines = 80

# Throttling prevents the same device/script from posting repeated alerts too frequently.
$TeamsAlertEnableThrottling = $true
$TeamsAlertThrottleMinutes = 1440
$TeamsAlertThrottleStateRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\AlertState'

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

# =========================
# TEAMS ALERT FUNCTIONS
# =========================

function Write-TeamsAlertStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    if (Get-Command -Name Write-Log -ErrorAction SilentlyContinue) {
        Write-Log -Message $Message -Level $Level
    }
    else {
        Write-Output $Message
    }
}

function Limit-TeamsAlertText {
    param(
        [AllowEmptyString()]
        [string]$Text,

        [int]$MaxCharacters = $TeamsAlertMaxDetailCharacters
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    if ($Text.Length -le $MaxCharacters) {
        return $Text
    }

    return ($Text.Substring(0, $MaxCharacters) + "`r`n...[truncated]")
}

function ConvertTo-TeamsAlertSafeFileName {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    $safeText = $Text

    foreach ($invalidChar in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safeText = $safeText.Replace([string]$invalidChar, '-')
    }

    $safeText = $safeText -replace '\s+', '-'
    $safeText = $safeText -replace '[^a-zA-Z0-9._-]', '-'
    $safeText = $safeText -replace '-+', '-'
    $safeText = $safeText.Trim('-')

    if ([string]::IsNullOrWhiteSpace($safeText)) {
        $safeText = 'TeamsAlert'
    }

    if ($safeText.Length -gt 80) {
        $safeText = $safeText.Substring(0, 80).Trim('-')
    }

    return $safeText
}

function Get-TeamsAlertStringHash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()

    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hashBytes = $sha256.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLowerInvariant())
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-TeamsAlertThrottleStatePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ThrottleKey,

        [Parameter(Mandatory = $true)]
        [string]$ScriptNameForAlert
    )

    $friendlyName = ConvertTo-TeamsAlertSafeFileName -Text "$TeamsAlertName-$ScriptNameForAlert-$TeamsAlertFlowTriggerTag"
    $hash = (Get-TeamsAlertStringHash -Text $ThrottleKey).Substring(0, 16)

    return (Join-Path -Path $TeamsAlertThrottleStateRoot -ChildPath "$friendlyName-$hash.json")
}

function Test-TeamsAlertThrottle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ThrottleKey,

        [Parameter(Mandatory = $true)]
        [string]$ScriptNameForAlert
    )

    if (-not $TeamsAlertEnableThrottling -or $TeamsAlertThrottleMinutes -le 0) {
        return [PSCustomObject]@{
            ShouldThrottle = $false
            StatePath      = $null
            LastAlertUtc   = $null
            NextAllowedUtc = $null
        }
    }

    $statePath = Get-TeamsAlertThrottleStatePath -ThrottleKey $ThrottleKey -ScriptNameForAlert $ScriptNameForAlert

    try {
        if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
            return [PSCustomObject]@{
                ShouldThrottle = $false
                StatePath      = $statePath
                LastAlertUtc   = $null
                NextAllowedUtc = $null
            }
        }

        $state = Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $dateTimeStyle = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
        $lastAlertUtc = [datetime]::Parse([string]$state.LastAlertUtc, [System.Globalization.CultureInfo]::InvariantCulture, $dateTimeStyle)
        $nextAllowedUtc = $lastAlertUtc.AddMinutes($TeamsAlertThrottleMinutes)

        return [PSCustomObject]@{
            ShouldThrottle = ((Get-Date).ToUniversalTime() -lt $nextAllowedUtc)
            StatePath      = $statePath
            LastAlertUtc   = $lastAlertUtc
            NextAllowedUtc = $nextAllowedUtc
        }
    }
    catch {
        Write-TeamsAlertStatus -Message "Teams alert throttling check failed. Sending alert anyway. $($_.Exception.Message)" -Level 'WARN'

        return [PSCustomObject]@{
            ShouldThrottle = $false
            StatePath      = $statePath
            LastAlertUtc   = $null
            NextAllowedUtc = $null
        }
    }
}

function Set-TeamsAlertThrottleState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ThrottleKey,

        [AllowEmptyString()]
        [string]$StatePath,

        [Parameter(Mandatory = $true)]
        [string]$ScriptNameForAlert,

        [Parameter(Mandatory = $true)]
        [string]$CorrelationId
    )

    if (-not $TeamsAlertEnableThrottling -or $TeamsAlertThrottleMinutes -le 0 -or [string]::IsNullOrWhiteSpace($StatePath)) {
        return
    }

    try {
        $stateFolder = Split-Path -Path $StatePath -Parent

        if (-not (Test-Path -LiteralPath $stateFolder -PathType Container)) {
            New-Item -Path $stateFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }

        $state = [PSCustomObject]@{
            ThrottleKey    = $ThrottleKey
            LastAlertUtc   = (Get-Date).ToUniversalTime().ToString('o')
            AlertName      = $TeamsAlertName
            ScriptName     = $ScriptNameForAlert
            FlowTriggerTag = $TeamsAlertFlowTriggerTag
            CorrelationId  = $CorrelationId
        }

        $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StatePath -Encoding UTF8 -Force -ErrorAction Stop
        Write-TeamsAlertStatus -Message "Teams alert throttle state updated: $StatePath"
    }
    catch {
        Write-TeamsAlertStatus -Message "Failed to update Teams alert throttle state. $($_.Exception.Message)" -Level 'WARN'
    }
}

function New-TeamsAlertFact {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,

        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return @{
        title = $Title
        value = $Value
    }
}

function New-TeamsAlertTextBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [string]$Weight = '',
        [string]$Size = '',
        [string]$Color = '',
        [string]$Spacing = '',
        [switch]$IsSubtle,
        [switch]$Monospace
    )

    $block = @{
        type = 'TextBlock'
        text = $Text
        wrap = $true
    }

    if (-not [string]::IsNullOrWhiteSpace($Weight)) {
        $block.weight = $Weight
    }

    if (-not [string]::IsNullOrWhiteSpace($Size)) {
        $block.size = $Size
    }

    if (-not [string]::IsNullOrWhiteSpace($Color)) {
        $block.color = $Color
    }

    if (-not [string]::IsNullOrWhiteSpace($Spacing)) {
        $block.spacing = $Spacing
    }

    if ($IsSubtle) {
        $block.isSubtle = $true
    }

    if ($Monospace) {
        $block.fontType = 'Monospace'
    }

    return $block
}

function Get-TeamsFailureDetails {
    param(
        [AllowEmptyString()]
        [string]$FailureDetails = '',

        [AllowEmptyString()]
        [string]$ScriptOutput = ''
    )

    $details = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($FailureDetails)) {
        $details.Add('Failure details:')
        $details.Add($FailureDetails)
    }

    if (-not [string]::IsNullOrWhiteSpace($ScriptOutput)) {
        $details.Add('')
        $details.Add('Script output:')
        $details.Add($ScriptOutput)
    }

    if ($TeamsAlertIncludeLogTail -and -not [string]::IsNullOrWhiteSpace($LogPath) -and (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
        try {
            $logTail = Get-Content -LiteralPath $LogPath -Tail $TeamsAlertLogTailLines -ErrorAction Stop

            if ($logTail.Count -gt 0) {
                $details.Add('')
                $details.Add('Log tail:')
                $details.Add(($logTail -join "`r`n"))
            }
        }
        catch {
            $details.Add('')
            $details.Add("Log tail could not be read: $($_.Exception.Message)")
        }
    }

    return (Limit-TeamsAlertText -Text ($details -join "`r`n"))
}

function Send-TeamsFailureAlert {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FailureMessage,

        [AllowEmptyString()]
        [string]$FailureDetails = '',

        [AllowEmptyString()]
        [string]$ScriptOutput = ''
    )

    if (-not $EnableTeamsFailureAlert) {
        return
    }

    if ([string]::IsNullOrWhiteSpace($TeamsWebhookUrl) -or $TeamsWebhookUrl -eq 'PASTE_TEAMS_WEBHOOK_URL_HERE') {
        Write-TeamsAlertStatus -Message 'Teams failure alerting is enabled, but the webhook URL is empty or still uses the placeholder.' -Level 'WARN'
        return
    }

    $deviceName = $env:COMPUTERNAME
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $correlationId = [guid]::NewGuid().ToString()
    $scriptNameForAlert = $ScriptName
    $powerShellVersion = $PSVersionTable.PSVersion.ToString()
    $is64BitProcess = [Environment]::Is64BitProcess.ToString()

    try {
        $executionIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }
    catch {
        $executionIdentity = 'Unable to detect identity'
    }

    if ($executionIdentity -eq 'NT AUTHORITY\SYSTEM') {
        $runContext = 'SYSTEM'
    }
    else {
        $runContext = 'User'
    }

    if ($TeamsAlertEnableThrottling) {
        $teamsAlertThrottleStatus = "$TeamsAlertThrottleMinutes minutes"
    }
    else {
        $teamsAlertThrottleStatus = 'Disabled'
    }

    try {
        $loggedOnUser = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).UserName

        if ([string]::IsNullOrWhiteSpace($loggedOnUser)) {
            $loggedOnUser = 'No interactive user'
        }
    }
    catch {
        $loggedOnUser = 'Unable to detect user'
    }

    $throttleKey = "$TeamsAlertSource|$TeamsAlertName|$scriptNameForAlert|$TeamsAlertFlowTriggerTag|$deviceName"
    $throttleResult = Test-TeamsAlertThrottle -ThrottleKey $throttleKey -ScriptNameForAlert $scriptNameForAlert

    if ($throttleResult.ShouldThrottle) {
        $lastAlertLocal = $throttleResult.LastAlertUtc.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss')
        $nextAllowedLocal = $throttleResult.NextAllowedUtc.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss')

        Write-TeamsAlertStatus -Message "Teams failure alert suppressed by throttling. Last alert: $lastAlertLocal. Next allowed: $nextAllowedLocal."
        return
    }

    $detailsText = Get-TeamsFailureDetails -FailureDetails $FailureDetails -ScriptOutput $ScriptOutput

    $cardBody = @(
        (New-TeamsAlertTextBlock -Text $TeamsAlertTitle -Weight 'Bolder' -Size 'Medium' -Color 'Attention'),
        (New-TeamsAlertTextBlock -Text $FailureMessage),
        @{
            type = 'FactSet'
            facts = @(
                (New-TeamsAlertFact -Title 'Source:' -Value $TeamsAlertSource)
                (New-TeamsAlertFact -Title 'Package:' -Value $TeamsAlertName)
                (New-TeamsAlertFact -Title 'Device:' -Value $deviceName)
                (New-TeamsAlertFact -Title 'User:' -Value $loggedOnUser)
                (New-TeamsAlertFact -Title 'Time:' -Value $timestamp)
            )
        },
        (New-TeamsAlertTextBlock -Text 'Technical Details' -Weight 'Bolder' -Spacing 'Medium'),
        @{
            type = 'FactSet'
            facts = @(
                (New-TeamsAlertFact -Title 'Script:' -Value $scriptNameForAlert)
                (New-TeamsAlertFact -Title 'Flow tag:' -Value $TeamsAlertFlowTriggerTag)
                (New-TeamsAlertFact -Title 'Correlation ID:' -Value $correlationId)
                (New-TeamsAlertFact -Title 'Throttle:' -Value $teamsAlertThrottleStatus)
                (New-TeamsAlertFact -Title 'PowerShell:' -Value $powerShellVersion)
                (New-TeamsAlertFact -Title '64-bit process:' -Value $is64BitProcess)
                (New-TeamsAlertFact -Title 'Run context:' -Value $runContext)
                (New-TeamsAlertFact -Title 'Running as:' -Value $executionIdentity)
            )
        }
    )

    if (-not [string]::IsNullOrWhiteSpace($detailsText)) {
        $cardBody += (New-TeamsAlertTextBlock -Text $detailsText -Spacing 'Medium' -Monospace)
    }

    $payload = @{
        type = 'message'
        attachments = @(
            @{
                contentType = 'application/vnd.microsoft.card.adaptive'
                content = @{
                    '$schema' = 'http://adaptivecards.io/schemas/adaptive-card.json'
                    type = 'AdaptiveCard'
                    version = '1.2'
                    body = $cardBody
                }
            }
        )
    } | ConvertTo-Json -Depth 20

    try {
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        }
        catch {
        }

        Invoke-RestMethod -Uri $TeamsWebhookUrl -Method Post -Body $payload -ContentType 'application/json' -TimeoutSec 15 -ErrorAction Stop | Out-Null
        Set-TeamsAlertThrottleState -ThrottleKey $throttleKey -StatePath $throttleResult.StatePath -ScriptNameForAlert $scriptNameForAlert -CorrelationId $correlationId
        Write-TeamsAlertStatus -Message 'Teams failure alert sent successfully.'
    }
    catch {
        Write-TeamsAlertStatus -Message "Failed to send Teams failure alert. $($_.Exception.Message)" -Level 'ERROR'
    }
}

# =========================
# DISK HEALTH FUNCTIONS
# =========================

function New-DiskFinding {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [AllowEmptyString()]
        [string]$SerialNumber = '',

        [AllowEmptyString()]
        [string]$BusType = '',

        [AllowEmptyString()]
        [string]$HealthStatus = '',

        [AllowEmptyString()]
        [string]$OperationalStatus = '',

        [Parameter(Mandatory = $true)]
        [string]$Reason
    )

    return [PSCustomObject]@{
        Source            = $Source
        Name              = $Name
        SerialNumber      = $SerialNumber
        BusType           = $BusType
        HealthStatus      = $HealthStatus
        OperationalStatus = $OperationalStatus
        Reason            = $Reason
    }
}

function ConvertTo-ComparableDeviceId {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    return (($Text.ToUpperInvariant()) -replace '[^A-Z0-9]', '')
}

function Get-NormalizedDriveLetter {
    param(
        [AllowEmptyString()]
        [string]$DriveLetter
    )

    $normalizedDriveLetter = ($DriveLetter -replace '[:\\]', '').Trim()

    if ([string]::IsNullOrWhiteSpace($normalizedDriveLetter)) {
        $normalizedDriveLetter = (($env:SystemDrive -replace '[:\\]', '').Trim())
    }

    if ([string]::IsNullOrWhiteSpace($normalizedDriveLetter)) {
        $normalizedDriveLetter = 'C'
    }

    return $normalizedDriveLetter.Substring(0, 1).ToUpperInvariant()
}

function Get-TargetDiskDrives {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveLetter
    )

    $normalizedDriveLetter = Get-NormalizedDriveLetter -DriveLetter $DriveLetter
    $logicalDiskId = "${normalizedDriveLetter}:"

    Write-Log -Message "Resolving target Windows drive '$logicalDiskId' to backing physical disk."

    $logicalDisk = Get-CimInstance -ClassName 'Win32_LogicalDisk' -Filter "DeviceID='$logicalDiskId'" -ErrorAction Stop

    if ($null -eq $logicalDisk) {
        throw "Logical disk '$logicalDiskId' was not found."
    }

    $partitions = @(Get-CimAssociatedInstance -InputObject $logicalDisk -Association 'Win32_LogicalDiskToPartition' -ErrorAction Stop)

    if ($partitions.Count -eq 0) {
        throw "No disk partition association was found for '$logicalDiskId'."
    }

    $diskDrivesByDeviceId = @{}

    foreach ($partition in $partitions) {
        $diskDrives = @(Get-CimAssociatedInstance -InputObject $partition -Association 'Win32_DiskDriveToDiskPartition' -ErrorAction Stop)

        foreach ($diskDrive in $diskDrives) {
            $deviceId = [string]$diskDrive.DeviceID

            if (-not [string]::IsNullOrWhiteSpace($deviceId) -and -not $diskDrivesByDeviceId.ContainsKey($deviceId)) {
                $diskDrivesByDeviceId[$deviceId] = $diskDrive
            }
        }
    }

    if ($diskDrivesByDeviceId.Count -eq 0) {
        throw "No physical disk association was found for '$logicalDiskId'."
    }

    foreach ($diskDrive in $diskDrivesByDeviceId.Values) {
        Write-Log -Message "Target disk resolved. DeviceID='$($diskDrive.DeviceID)'; Index='$($diskDrive.Index)'; Model='$($diskDrive.Model)'; Serial='$($diskDrive.SerialNumber)'; PNPDeviceID='$($diskDrive.PNPDeviceID)'; Status='$($diskDrive.Status)'."
    }

    return @($diskDrivesByDeviceId.Values)
}

function Get-MatchingTargetDiskDriveForSmartInstance {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstanceName,

        [Parameter(Mandatory = $true)]
        [object[]]$TargetDiskDrives
    )

    $smartComparable = ConvertTo-ComparableDeviceId -Text $InstanceName

    foreach ($diskDrive in $TargetDiskDrives) {
        $diskComparable = ConvertTo-ComparableDeviceId -Text ([string]$diskDrive.PNPDeviceID)

        if (-not [string]::IsNullOrWhiteSpace($diskComparable) -and ($smartComparable -like "*$diskComparable*" -or $diskComparable -like "*$smartComparable*")) {
            return $diskDrive
        }
    }

    return $null
}

function Get-SmartPredictiveFailureFindings {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$TargetDiskDrives
    )

    $findings = New-Object System.Collections.Generic.List[object]

    if (-not $CheckSmartPredictiveFailure) {
        Write-Log -Message 'SMART predictive failure check is disabled.'
        return @($findings)
    }

    try {
        $smartStatuses = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'MSStorageDriver_FailurePredictStatus' -ErrorAction Stop)
        Write-Log -Message "SMART predictive status instances found: $($smartStatuses.Count)."

        foreach ($smartStatus in $smartStatuses) {
            $instanceName = [string]$smartStatus.InstanceName
            $predictFailure = [bool]$smartStatus.PredictFailure
            $targetDiskDrive = Get-MatchingTargetDiskDriveForSmartInstance -InstanceName $instanceName -TargetDiskDrives $TargetDiskDrives

            if ($null -eq $targetDiskDrive) {
                Write-Log -Message "Skipping SMART instance '$instanceName' because it does not match the target Windows disk."
                continue
            }

            Write-Log -Message "Target Windows disk SMART instance '$instanceName' reports PredictFailure='$predictFailure'."

            if ($predictFailure) {
                $findings.Add((New-DiskFinding `
                    -Source 'MSStorageDriver_FailurePredictStatus' `
                    -Name ([string]$targetDiskDrive.Model) `
                    -SerialNumber ([string]$targetDiskDrive.SerialNumber) `
                    -BusType ([string]$targetDiskDrive.InterfaceType) `
                    -Reason 'SMART predictive failure is true.'))
            }
        }
    }
    catch {
        Write-Log -Message "SMART predictive failure query failed. $($_.Exception.Message)" -Level 'WARN'
    }

    return @($findings)
}

function Get-DiskHealthFallbackFindings {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$TargetDiskDrives
    )

    $findings = New-Object System.Collections.Generic.List[object]

    if (-not $CheckDiskHealthFallback) {
        Write-Log -Message 'Disk health fallback is disabled.'
        return @($findings)
    }

    foreach ($diskDrive in $TargetDiskDrives) {
        $name = [string]$diskDrive.Model
        $serialNumber = [string]$diskDrive.SerialNumber
        $busType = [string]$diskDrive.InterfaceType
        $win32Status = [string]$diskDrive.Status

        Write-Log -Message "Target Windows disk fallback status. DeviceID='$($diskDrive.DeviceID)'; Index='$($diskDrive.Index)'; Model='$name'; Serial='$serialNumber'; InterfaceType='$busType'; Win32Status='$win32Status'."

        if ($UnhealthyWin32DiskStatuses -contains $win32Status) {
            $findings.Add((New-DiskFinding `
                -Source 'Win32_DiskDrive' `
                -Name $name `
                -SerialNumber $serialNumber `
                -BusType $busType `
                -HealthStatus $win32Status `
                -Reason "Win32_DiskDrive status is '$win32Status'."))
        }

        if (-not (Get-Command -Name Get-Disk -ErrorAction SilentlyContinue)) {
            Write-Log -Message 'Get-Disk is not available on this device.' -Level 'WARN'
            continue
        }

        try {
            $storageDisk = Get-Disk -Number ([int]$diskDrive.Index) -ErrorAction Stop
            $healthStatus = [string]$storageDisk.HealthStatus
            $operationalStatus = (($storageDisk.OperationalStatus | ForEach-Object { [string]$_ }) -join ', ')
            $storageBusType = [string]$storageDisk.BusType

            Write-Log -Message "Target Windows disk Get-Disk status. Number='$($storageDisk.Number)'; FriendlyName='$($storageDisk.FriendlyName)'; Serial='$($storageDisk.SerialNumber)'; BusType='$storageBusType'; HealthStatus='$healthStatus'; OperationalStatus='$operationalStatus'."

            if ($UnhealthyDiskHealthStatuses -contains $healthStatus) {
                $findings.Add((New-DiskFinding `
                    -Source 'Get-Disk' `
                    -Name ([string]$storageDisk.FriendlyName) `
                    -SerialNumber ([string]$storageDisk.SerialNumber) `
                    -BusType $storageBusType `
                    -HealthStatus $healthStatus `
                    -OperationalStatus $operationalStatus `
                    -Reason "Disk health status is '$healthStatus'."))

                continue
            }

            foreach ($unhealthyOperationalStatus in $UnhealthyDiskOperationalStatuses) {
                if ($operationalStatus -like "*$unhealthyOperationalStatus*") {
                    $findings.Add((New-DiskFinding `
                        -Source 'Get-Disk' `
                        -Name ([string]$storageDisk.FriendlyName) `
                        -SerialNumber ([string]$storageDisk.SerialNumber) `
                        -BusType $storageBusType `
                        -HealthStatus $healthStatus `
                        -OperationalStatus $operationalStatus `
                        -Reason "Disk operational status includes '$unhealthyOperationalStatus'."))

                    break
                }
            }
        }
        catch {
            Write-Log -Message "Get-Disk fallback query failed for target disk index '$($diskDrive.Index)'. $($_.Exception.Message)" -Level 'WARN'
        }
    }

    return @($findings)
}

function Convert-FindingToText {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Finding
    )

    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add("Source='$($Finding.Source)'")
    $parts.Add("Name='$($Finding.Name)'")

    if (-not [string]::IsNullOrWhiteSpace($Finding.SerialNumber)) {
        $parts.Add("Serial='$($Finding.SerialNumber)'")
    }

    if (-not [string]::IsNullOrWhiteSpace($Finding.BusType)) {
        $parts.Add("BusType='$($Finding.BusType)'")
    }

    if (-not [string]::IsNullOrWhiteSpace($Finding.HealthStatus)) {
        $parts.Add("HealthStatus='$($Finding.HealthStatus)'")
    }

    if (-not [string]::IsNullOrWhiteSpace($Finding.OperationalStatus)) {
        $parts.Add("OperationalStatus='$($Finding.OperationalStatus)'")
    }

    $parts.Add("Reason='$($Finding.Reason)'")

    return ($parts -join '; ')
}

function Get-DiskPredictiveFailureFindings {
    $targetDiskDrives = @(Get-TargetDiskDrives -DriveLetter $TargetDriveLetter)
    $findings = @()
    $findings += @(Get-SmartPredictiveFailureFindings -TargetDiskDrives $targetDiskDrives)
    $findings += @(Get-DiskHealthFallbackFindings -TargetDiskDrives $targetDiskDrives)
    return @($findings)
}

# =========================
# MAIN
# =========================

try {
    Initialize-Log
    Write-ScriptMetadata
    Write-Log -Message "Remediation started. TargetDriveLetter='$TargetDriveLetter'. This script records Windows disk predictive failure findings and does not attempt hardware repair."

    $findings = @(Get-DiskPredictiveFailureFindings)

    if ($findings.Count -eq 0) {
        Write-Log -Message 'No Windows disk predictive failure detected during remediation validation.'
        Write-Output 'No Windows disk predictive failure detected.'
        exit 0
    }

    $findingText = (($findings | ForEach-Object { Convert-FindingToText -Finding $_ }) -join "`r`n")
    $scriptOutput = "Manual action required. Back up the device, review vendor diagnostics, and plan disk replacement. This script does not attempt automated hardware repair."

    Write-Log -Message "Windows disk predictive failure remains. Findings: $($findings.Count)." -Level 'ERROR'

    foreach ($finding in $findings) {
        Write-Log -Message (Convert-FindingToText -Finding $finding) -Level 'ERROR'
    }

    Send-TeamsFailureAlert `
        -FailureMessage "Predictive failure detected on the Windows disk for device '$env:COMPUTERNAME'." `
        -FailureDetails $findingText `
        -ScriptOutput $scriptOutput

    Write-Output "Windows disk predictive failure detected. Findings: $($findings.Count)."

    if ($ExitOneWhenPredictiveFailureRemains) {
        exit 1
    }

    exit 0
}
catch {
    $errorMessage = $_.Exception.Message

    try {
        Write-Log -Message "Remediation failed. $errorMessage" -Level 'ERROR'

        Send-TeamsFailureAlert `
            -FailureMessage "Disk predictive failure remediation script failed on device '$env:COMPUTERNAME'." `
            -FailureDetails $errorMessage
    }
    catch {
    }

    Write-Output 'Disk predictive failure remediation script failed.'
    exit 1
}

