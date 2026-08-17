<#
.SYNOPSIS
    Standalone Microsoft Teams alert test with dummy Intune remediation data.

.DESCRIPTION
    Copy this entire script into PowerShell ISE, VS Code, or a .ps1 file.
    Edit the CONFIGURATION section, then run it from Windows PowerShell 5.1.

    The script is intentionally self-contained:
    - No repo paths.
    - No external modules.
    - No parameters.
    - No Intune dependency.
    - No required log file.

.NOTES
    Name:        Test-TeamsFailureAlert.ps1
    Version:     1.0.3
    PowerShell:  Windows PowerShell 5.1
#>

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

# ============================================================
# CONFIGURATION
# ============================================================

# Quick test:
# 1. Copy this file to Test-TeamsFailureAlert.local.ps1.
# 2. Paste your Teams webhook URL into $TeamsWebhookUrl in the local copy.
# 3. Set $SendTeamsAlert = $true in the local copy.
# 4. Run the local copy in Windows PowerShell 5.1.
# 5. Check the target Teams channel or workflow.
#
# Files ending in .local.ps1 are ignored by this repository.
$SendTeamsAlert = $false

# CUSTOMIZE HERE in your local test copy.
# Paste your own Teams webhook URL here only when testing.
# Do not commit a real webhook URL to GitHub.
$TeamsWebhookUrl = ''

# Set to $true only when you want to inspect the raw Adaptive Card JSON.
$ShowJsonPreview = $false

# Maximum characters for large detail fields.
$MaxDetailCharacters = 3500

# Throttling prevents repeated test alerts from posting too frequently.
# Set $ResetAlertThrottleState to $true once if you want to force another test alert.
$EnableAlertThrottling = $true
$AlertThrottleMinutes = 1440
$ResetAlertThrottleState = $false
$AlertThrottleStateRoot = Join-Path -Path $env:TEMP -ChildPath 'IntuneScriptLibrary\TeamsAlertTestState'

# ============================================================
# DUMMY ALERT DATA
# Change these values to shape the card content.
# ============================================================

$AlertTitle = 'Intune Remediation Failed'
$AlertSubtitle = 'Detection succeeded, but remediation failed during validation.'
$AlertSource = 'Microsoft Intune Remediation'
$Severity = 'High'
$RemediationName = 'Defender-Enable-Network-Protection'
$Category = 'Detection-Remediation / Security'
$ScriptName = 'Remediate.ps1'
$DeviceName = 'LAPTOP-1042'
$LoggedOnUser = 'CONTOSO\jane.doe'
$ExitCode = '1'
$TenantName = 'Contoso'
$AssignmentName = 'Pilot - Security Remediations'
$Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

# Stable tag for downstream automation.
# Keep this value short, unique, and without spaces so another flow can match it easily.
$FlowTriggerTag = 'INTUNE_REMEDIATION_FAILURE'

# Correlation ID helps connect Teams alerts, Intune reports, and local logs.
$CorrelationId = [guid]::NewGuid().ToString()

# Runtime facts are useful when troubleshooting Intune context issues.
$PowerShellVersion = $PSVersionTable.PSVersion.ToString()
$Is64BitProcess = [Environment]::Is64BitProcess.ToString()

try {
    $ExecutionIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
}
catch {
    $ExecutionIdentity = 'Unable to detect identity'
}

if ($ExecutionIdentity -eq 'NT AUTHORITY\SYSTEM') {
    $RunContext = 'SYSTEM'
}
else {
    $RunContext = 'User'
}

if ($EnableAlertThrottling) {
    $AlertThrottleStatus = "$AlertThrottleMinutes minutes"
}
else {
    $AlertThrottleStatus = 'Disabled'
}

$FailureMessage = "Network Protection was set to 'Enabled', but validation returned 'Disabled'."

$FailureDetails = @'
Set-MpPreference completed without throwing an exception.
Get-MpPreference still returned EnableNetworkProtection = Disabled.

Possible causes:
- Another security policy or baseline controls the setting.
- Tamper Protection blocked the change.
- Microsoft Defender Antivirus platform state is not ready.
'@

$ScriptOutput = @'
[INFO] Remediation started. DesiredNetworkProtection='Enabled'.
[INFO] Current Defender Network Protection value is 'Disabled'.
[INFO] Setting Defender Network Protection to 'Enabled'.
[ERROR] Remediation failed. Defender Network Protection is 'Disabled'. Expected 'Enabled'.
'@

$LogTail = @'
2026-05-15 10:41:12 [INFO] Script metadata: Package='Defender-Enable-Network-Protection'; Script='Remediate'; User='NT AUTHORITY\SYSTEM'; PowerShell='5.1.22621.2506'; Is64BitProcess='True'.
2026-05-15 10:41:12 [INFO] Remediation started. DesiredNetworkProtection='Enabled'.
2026-05-15 10:41:12 [INFO] Current Defender Network Protection value is 'Disabled'.
2026-05-15 10:41:12 [INFO] Setting Defender Network Protection to 'Enabled'.
2026-05-15 10:41:15 [ERROR] Remediation failed. Defender Network Protection is 'Disabled'. Expected 'Enabled'.
'@

# ============================================================
# FUNCTIONS
# ============================================================

function Limit-Text {
    param(
        [AllowEmptyString()]
        [string]$Text,

        [int]$MaxCharacters = $MaxDetailCharacters
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    if ($Text.Length -le $MaxCharacters) {
        return $Text
    }

    return ($Text.Substring(0, $MaxCharacters) + "`r`n...[truncated]")
}

function ConvertTo-SafeFileName {
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

function Get-StableHash {
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

function Get-AlertThrottleStatePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ThrottleKey
    )

    $friendlyName = ConvertTo-SafeFileName -Text "$RemediationName-$ScriptName-$FlowTriggerTag"
    $hash = (Get-StableHash -Text $ThrottleKey).Substring(0, 16)

    return (Join-Path -Path $AlertThrottleStateRoot -ChildPath "$friendlyName-$hash.json")
}

function Test-AlertThrottle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ThrottleKey
    )

    if (-not $EnableAlertThrottling -or $AlertThrottleMinutes -le 0) {
        return [PSCustomObject]@{
            ShouldThrottle = $false
            StatePath      = $null
            LastAlertUtc   = $null
            NextAllowedUtc = $null
        }
    }

    $statePath = Get-AlertThrottleStatePath -ThrottleKey $ThrottleKey

    try {
        if ($ResetAlertThrottleState -and (Test-Path -LiteralPath $statePath -PathType Leaf)) {
            Remove-Item -LiteralPath $statePath -Force -ErrorAction Stop
            Write-Output "Removed alert throttle state: $statePath"
        }

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
        $nextAllowedUtc = $lastAlertUtc.AddMinutes($AlertThrottleMinutes)

        return [PSCustomObject]@{
            ShouldThrottle = ((Get-Date).ToUniversalTime() -lt $nextAllowedUtc)
            StatePath      = $statePath
            LastAlertUtc   = $lastAlertUtc
            NextAllowedUtc = $nextAllowedUtc
        }
    }
    catch {
        Write-Output "Alert throttling check failed. Sending alert anyway. $($_.Exception.Message)"

        return [PSCustomObject]@{
            ShouldThrottle = $false
            StatePath      = $statePath
            LastAlertUtc   = $null
            NextAllowedUtc = $null
        }
    }
}

function Set-AlertThrottleState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ThrottleKey,

        [AllowEmptyString()]
        [string]$StatePath,

        [Parameter(Mandatory = $true)]
        [string]$CorrelationIdValue
    )

    if (-not $EnableAlertThrottling -or $AlertThrottleMinutes -le 0 -or [string]::IsNullOrWhiteSpace($StatePath)) {
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
            AlertName      = $RemediationName
            ScriptName     = $ScriptName
            FlowTriggerTag = $FlowTriggerTag
            CorrelationId  = $CorrelationIdValue
        }

        $state | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StatePath -Encoding UTF8 -Force -ErrorAction Stop
        Write-Output "Updated alert throttle state: $StatePath"
    }
    catch {
        Write-Output "Failed to update alert throttle state. $($_.Exception.Message)"
    }
}

function New-TeamsFact {
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

function New-CardTextBlock {
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

function New-SectionHeader {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text
    )

    return New-CardTextBlock -Text $Text -Weight 'Bolder' -Spacing 'Medium'
}

function Get-SeverityColor {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SeverityValue
    )

    switch ($SeverityValue) {
        'Low' { return 'Good' }
        'Medium' { return 'Warning' }
        'High' { return 'Attention' }
        default { return 'Attention' }
    }
}

function New-TeamsFailureAlertPayload {
    $severityColor = Get-SeverityColor -SeverityValue $Severity

    $cardBody = @(
        (New-CardTextBlock -Text $AlertTitle -Weight 'Bolder' -Size 'Large' -Color $severityColor),
        (New-CardTextBlock -Text $AlertSubtitle -Spacing 'Small' -IsSubtle),
        @{
            type = 'FactSet'
            spacing = 'Medium'
            facts = @(
                (New-TeamsFact -Title 'Source:' -Value $AlertSource)
                (New-TeamsFact -Title 'Severity:' -Value $Severity)
                (New-TeamsFact -Title 'Remediation:' -Value $RemediationName)
                (New-TeamsFact -Title 'Device:' -Value $DeviceName)
                (New-TeamsFact -Title 'User:' -Value $LoggedOnUser)
                (New-TeamsFact -Title 'Time:' -Value $Timestamp)
            )
        },
        (New-SectionHeader -Text 'Failure Message'),
        (New-CardTextBlock -Text $FailureMessage -Color 'Attention'),
        (New-SectionHeader -Text 'Failure Details'),
        (New-CardTextBlock -Text (Limit-Text -Text $FailureDetails) -Spacing 'Small'),
        (New-SectionHeader -Text 'Technical Details'),
        @{
            type = 'FactSet'
            spacing = 'Small'
            facts = @(
                (New-TeamsFact -Title 'Category:' -Value $Category)
                (New-TeamsFact -Title 'Script:' -Value $ScriptName)
                (New-TeamsFact -Title 'Exit code:' -Value $ExitCode)
                (New-TeamsFact -Title 'Tenant:' -Value $TenantName)
                (New-TeamsFact -Title 'Assignment:' -Value $AssignmentName)
                (New-TeamsFact -Title 'Flow tag:' -Value $FlowTriggerTag)
                (New-TeamsFact -Title 'Correlation ID:' -Value $CorrelationId)
                (New-TeamsFact -Title 'Throttle:' -Value $AlertThrottleStatus)
                (New-TeamsFact -Title 'PowerShell:' -Value $PowerShellVersion)
                (New-TeamsFact -Title '64-bit process:' -Value $Is64BitProcess)
                (New-TeamsFact -Title 'Run context:' -Value $RunContext)
                (New-TeamsFact -Title 'Running as:' -Value $ExecutionIdentity)
            )
        },
        (New-SectionHeader -Text 'Script Output'),
        (New-CardTextBlock -Text (Limit-Text -Text $ScriptOutput) -Spacing 'Small' -Monospace),
        (New-SectionHeader -Text 'Log Tail'),
        (New-CardTextBlock -Text (Limit-Text -Text $LogTail) -Spacing 'Small' -IsSubtle -Monospace)
    )

    return @{
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
    }
}

# ============================================================
# MAIN
# ============================================================

try {
    $payload = New-TeamsFailureAlertPayload
    $payloadJson = $payload | ConvertTo-Json -Depth 30

    if ($ShowJsonPreview) {
        Write-Output '==================== JSON PREVIEW ===================='
        Write-Output $payloadJson
        Write-Output '================== END JSON PREVIEW =================='
    }

    if (-not $SendTeamsAlert) {
        Write-Output 'SendTeamsAlert is false. No Teams message was sent.'
        Write-Output 'Set $SendTeamsAlert = $true and paste your webhook URL to send the dummy alert.'
        exit 0
    }

    if ([string]::IsNullOrWhiteSpace($TeamsWebhookUrl) -or $TeamsWebhookUrl -eq 'PASTE_TEAMS_WEBHOOK_URL_HERE') {
        Write-Output 'TeamsWebhookUrl is empty or still uses the placeholder. No Teams message was sent.'
        Write-Output 'Paste your Teams webhook URL into $TeamsWebhookUrl near the top of this script, then run it again.'
        exit 1
    }

    $throttleKey = "$AlertSource|$RemediationName|$ScriptName|$FlowTriggerTag|$DeviceName"
    $throttleResult = Test-AlertThrottle -ThrottleKey $throttleKey

    if ($throttleResult.ShouldThrottle) {
        $lastAlertLocal = $throttleResult.LastAlertUtc.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss')
        $nextAllowedLocal = $throttleResult.NextAllowedUtc.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss')

        Write-Output "Dummy Teams alert suppressed by throttling. Last alert: $lastAlertLocal. Next allowed: $nextAllowedLocal."
        Write-Output "Set `$ResetAlertThrottleState = `$true once, lower `$AlertThrottleMinutes, or set `$EnableAlertThrottling = `$false to force another test."
        exit 0
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }
    catch {
    }

    Invoke-RestMethod `
        -Uri $TeamsWebhookUrl `
        -Method Post `
        -Body $payloadJson `
        -ContentType 'application/json' `
        -TimeoutSec 15 `
        -ErrorAction Stop | Out-Null

    Set-AlertThrottleState -ThrottleKey $throttleKey -StatePath $throttleResult.StatePath -CorrelationIdValue $CorrelationId

    Write-Output 'Dummy Teams alert sent successfully.'
    exit 0
}
catch {
    Write-Output "Failed to create or send dummy Teams alert. $($_.Exception.Message)"
    exit 1
}
