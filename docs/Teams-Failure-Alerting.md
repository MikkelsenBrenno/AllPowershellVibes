# Teams Failure Alerting

This repository includes an optional Microsoft Teams failure alerting pattern for scripts that should notify a channel when a remediation, install, or uninstall action fails.

Use this pattern carefully. Detection scripts often exit `1` for normal noncompliance, so do not send alerts from detection scripts unless the script itself crashes.

## Template

Use:

```text
templates/TeamsFailureAlert.Template.ps1
```

Copy the block into scripts that need alerting. Keep it disabled by default in source control.

The block is intentionally optional. When `$EnableTeamsFailureAlert` is `$false`, `Send-TeamsFailureAlert` silently returns and does not call the webhook. The calling script still controls the real Intune exit code.

When creating new script folders with the helper, add the block to supported action scripts with:

```powershell
.\tools\New-IntuneScriptFolder.ps1 -Workload Detection-Remediation -ScriptCategory Security -Name Defender-Example-Recommendation -IncludeTeamsAlertBlock
```

The helper adds the block to:

- Detection & Remediation: `Remediate.ps1`
- Intune Platform Scripts: the generated script file
- Win32 Packaged Scripts: `Install.ps1` and `Uninstall.ps1`

It does not add the block to detection or custom compliance discovery scripts by default, because those scripts often use exit codes or JSON output as normal Intune signaling.

## Manual Card Design Test

Use the standalone test script when shaping the Teams card:

```powershell
.\tools\Test-TeamsFailureAlert.ps1
```

The repository copy is safe by default and does not send alerts. For a real test, create a local ignored copy first:

```powershell
Copy-Item .\tools\Test-TeamsFailureAlert.ps1 .\tools\Test-TeamsFailureAlert.local.ps1
```

Then edit `Test-TeamsFailureAlert.local.ps1`:

```powershell
$SendTeamsAlert = $true
$TeamsWebhookUrl = '<Paste your own webhook URL here>'
```

Files ending in `.local.ps1` are ignored by the repository. Set `$ShowJsonPreview` to `$true` when you want to inspect the raw Adaptive Card JSON without focusing on delivery.

## Configuration

```powershell
$EnableTeamsFailureAlert = $false
$TeamsWebhookUrl = ''
$TeamsAlertName = $ScriptPackageName
$TeamsAlertTitle = 'Intune Script Failure'
$TeamsAlertSource = 'Microsoft Intune Remediation'
$TeamsAlertMaxDetailCharacters = 5000
$TeamsAlertIncludeLogTail = $true
$TeamsAlertLogTailLines = 80
$TeamsAlertEnableThrottling = $true
$TeamsAlertThrottleMinutes = 1440
$TeamsAlertThrottleStateRoot = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\IntuneScriptLibrary\AlertState'
$TeamsAlertFlowTriggerTag = 'INTUNE_REMEDIATION_FAILURE'
```

Set `$EnableTeamsFailureAlert` to `$true` only where alerts should be sent.

Do not commit a real Teams webhook URL. Treat webhook URLs as secrets because anyone with the URL can post to the target channel or workflow.

Admins should set `$TeamsWebhookUrl` in their own deployed copy of the script. Repository examples and templates should keep the webhook blank or use a placeholder.

## What Gets Sent

The alert includes:

- Failure message.
- Alert source.
- Script package name.
- Device name.
- Logged-on user when available.
- Timestamp.
- Failure details.
- Script name.
- Flow trigger tag.
- Correlation ID.
- Alert throttle window.
- PowerShell version.
- 64-bit process state.
- Run context and execution identity.
- Script output when passed to the function.
- Tail of the script log when `$LogPath` exists.

The card layout keeps triage information near the top and moves technical details, runtime facts, automation tags, script output, and log tail content toward the bottom.

## Alert Throttling

Throttling prevents the same device/script from posting repeated alerts too frequently. This is useful when an Intune remediation runs on a schedule and the same issue remains broken for multiple runs.

By default, the template allows one alert per device/script/flow tag every 24 hours. The state is stored locally on the device under:

```text
C:\ProgramData\Microsoft\IntuneScriptLibrary\AlertState
```

The throttle state is updated only after a Teams alert is sent successfully. If the throttle state cannot be read or written, the script logs that condition and continues trying to send the alert.

To disable throttling for a script:

```powershell
$TeamsAlertEnableThrottling = $false
```

To change the window:

```powershell
$TeamsAlertThrottleMinutes = 60
```

## Recommended Usage

Use the function in remediation failure paths:

```powershell
catch {
    $failureDetails = $_.Exception.Message

    try {
        Write-Log -Message "Remediation failed. $failureDetails" -Level 'ERROR'
        Send-TeamsFailureAlert `
            -FailureMessage "Remediation failed: $ScriptPackageName" `
            -FailureDetails $failureDetails
    }
    catch {
    }

    Write-Output "Remediation failed for '$ScriptPackageName'."
    exit 1
}
```

If your script captures output in a buffer, pass it as `ScriptOutput`:

```powershell
$scriptOutputBuffer = New-Object System.Collections.Generic.List[string]

function Write-RunOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $scriptOutputBuffer.Add($Message)
    Write-Output $Message
}

Send-TeamsFailureAlert `
    -FailureMessage "Remediation failed: $ScriptPackageName" `
    -FailureDetails $_.Exception.Message `
    -ScriptOutput ($scriptOutputBuffer -join "`r`n")
```

Most scripts in this repository already write useful detail to a log file, so the alert template also includes the log tail automatically when `$LogPath` is available.

## Flow Routing Tag

The card includes a stable `Flow tag` fact, for example `INTUNE_REMEDIATION_FAILURE`.

Use this value when another Teams, Logic Apps, or Power Automate flow needs to route or trigger from the alert. Keep the tag short, unique, and without spaces so a flow can check for it with a simple `contains()` condition.

Example tag values:

- `INTUNE_REMEDIATION_FAILURE`
- `INTUNE_WIN32_INSTALL_FAILURE`
- `INTUNE_COMPLIANCE_DISCOVERY_FAILURE`

Each alert also includes a correlation ID. Use it when comparing the Teams alert with local script logs or Intune reporting output.

## Intune Notes

- Keep alerting disabled until webhook delivery is tested.
- Use system context for device remediation scripts.
- Avoid sending sensitive user data, tokens, secrets, or full command output.
- Keep alert details short enough for Teams cards to remain readable.
- If another policy manages the same setting, fix the policy conflict instead of relying only on alerts.

## Teams Notes

Microsoft Teams supports posting Adaptive Card payloads to webhook-based integrations, but availability depends on tenant policy and the current Teams connector or workflow model. Test the webhook in your tenant before broad deployment.

## Validation

`tools/Test-Repository.ps1` fails if a PowerShell file contains a committed Teams webhook URL in `$TeamsWebhookUrl`.
