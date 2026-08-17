<#
.SYNOPSIS
    Optional Microsoft Teams failure alerting block for Intune scripts.

.DESCRIPTION
    Copy this block into a remediation script when failures should post to
    Microsoft Teams. Alerting is disabled by default. The webhook URL should
    never be committed to a public repository.

    When $EnableTeamsFailureAlert is $false, Send-TeamsFailureAlert silently
    returns and does not send a webhook request. This block should not
    decide the Intune exit code; the calling script should still handle success
    or failure normally.

.NOTES
    PowerShell: Windows PowerShell 5.1
    Intended use: Remediation failure path, install failure path, or uninstall failure path.
#>

# =========================
# OPTIONAL TEAMS FAILURE ALERTING
# =========================

# CUSTOMIZE HERE in the deployed copy only.
# Keep the repository copy disabled and without a webhook URL.
# Admins can paste their own webhook URL after they decide to use Teams alerts.

# Set to $true only in scripts where Teams alerting should be active.
# When this is $false, Send-TeamsFailureAlert silently returns and the script continues.
$EnableTeamsFailureAlert = $false

# Treat this URL as a secret. Do not commit a real webhook URL to GitHub.
# Admins should set this in their deployed/customized copy of the script.
$TeamsWebhookUrl = ''

# This should usually match the script package name.
$TeamsAlertName = $ScriptPackageName

# Card title shown at the top of the Teams alert.
$TeamsAlertTitle = 'Intune Script Failure'

# Identifies where the alert came from when a channel receives messages from multiple systems.
$TeamsAlertSource = 'Microsoft Intune Remediation'

# Keep details compact enough for Teams cards and readable channel messages.
$TeamsAlertMaxDetailCharacters = 5000

# Include the last lines of the script log in the Teams alert when available.
$TeamsAlertIncludeLogTail = $true
$TeamsAlertLogTailLines = 80

# Throttling prevents the same device/script from posting repeated alerts too frequently.
$TeamsAlertEnableThrottling = $true
$TeamsAlertThrottleMinutes = 1440
$TeamsAlertThrottleStateRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\AlertState'

# Stable tag for downstream automation.
# Keep this value short, unique, and without spaces so another flow can match it easily.
$TeamsAlertFlowTriggerTag = 'INTUNE_REMEDIATION_FAILURE'

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

function Get-TeamsFailureDetails {
    param(
        [AllowEmptyString()]
        [string]$FailureDetails = '',

        [AllowEmptyString()]
        [string]$ScriptOutput = ''
    )

    $details = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($FailureDetails)) {
        $details.Add("Failure details:")
        $details.Add($FailureDetails)
    }

    if (-not [string]::IsNullOrWhiteSpace($ScriptOutput)) {
        $details.Add('')
        $details.Add("Script output:")
        $details.Add($ScriptOutput)
    }

    $logPathVariable = Get-Variable -Name LogPath -ErrorAction SilentlyContinue

    if ($TeamsAlertIncludeLogTail -and $null -ne $logPathVariable -and -not [string]::IsNullOrWhiteSpace($logPathVariable.Value)) {
        $currentLogPath = [string]$logPathVariable.Value

        if (Test-Path -LiteralPath $currentLogPath -PathType Leaf) {
            try {
                $logTail = Get-Content -LiteralPath $currentLogPath -Tail $TeamsAlertLogTailLines -ErrorAction Stop

                if ($logTail.Count -gt 0) {
                    $details.Add('')
                    $details.Add("Log tail:")
                    $details.Add(($logTail -join "`r`n"))
                }
            }
            catch {
                $details.Add('')
                $details.Add("Log tail could not be read: $($_.Exception.Message)")
            }
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
    $scriptNameForAlert = 'Unknown'
    $powerShellVersion = $PSVersionTable.PSVersion.ToString()
    $is64BitProcess = [Environment]::Is64BitProcess.ToString()

    if (Get-Variable -Name ScriptName -ErrorAction SilentlyContinue) {
        $scriptNameForAlert = $ScriptName
    }

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
        @{
            type = 'TextBlock'
            text = $TeamsAlertTitle
            weight = 'Bolder'
            size = 'Medium'
            wrap = $true
        },
        @{
            type = 'TextBlock'
            text = $FailureMessage
            wrap = $true
        },
        @{
            type = 'FactSet'
            facts = @(
                @{
                    title = 'Source:'
                    value = $TeamsAlertSource
                },
                @{
                    title = 'Package:'
                    value = $TeamsAlertName
                },
                @{
                    title = 'Device:'
                    value = $deviceName
                },
                @{
                    title = 'User:'
                    value = $loggedOnUser
                },
                @{
                    title = 'Time:'
                    value = $timestamp
                }
            )
        }
    )

    $cardBody += @{
        type = 'TextBlock'
        text = 'Technical Details'
        weight = 'Bolder'
        spacing = 'Medium'
        wrap = $true
    }

    $cardBody += @{
        type = 'FactSet'
        facts = @(
            @{
                title = 'Script:'
                value = $scriptNameForAlert
            },
            @{
                title = 'Flow tag:'
                value = $TeamsAlertFlowTriggerTag
            },
            @{
                title = 'Correlation ID:'
                value = $correlationId
            },
            @{
                title = 'Throttle:'
                value = $teamsAlertThrottleStatus
            },
            @{
                title = 'PowerShell:'
                value = $powerShellVersion
            },
            @{
                title = '64-bit process:'
                value = $is64BitProcess
            },
            @{
                title = 'Run context:'
                value = $runContext
            },
            @{
                title = 'Running as:'
                value = $executionIdentity
            }
        )
    }

    if (-not [string]::IsNullOrWhiteSpace($detailsText)) {
        $cardBody += @{
            type = 'TextBlock'
            text = $detailsText
            wrap = $true
            spacing = 'Medium'
        }
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
