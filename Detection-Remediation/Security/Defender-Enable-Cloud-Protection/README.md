# Defender: Enable Cloud Protection

## Summary

This remediation package checks Microsoft Defender cloud protection settings and remediates them when needed.

The default configuration sets `MAPSReporting` to `Advanced` and `SubmitSamplesConsent` to `SendSafeSamples`. Review your organization's privacy requirements before changing sample submission to `SendAllSamples`.

## Files

- `Detect.ps1` - Checks `MAPSReporting` and `SubmitSamplesConsent`.
- `Remediate.ps1` - Configures both values and validates the final state.

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Defender Antivirus available on the target device.
- PowerShell 5.1.
- System context recommended.
- 64-bit PowerShell recommended.

## Customization

Update the `CONFIGURATION` section in both scripts.

| Setting | Description | Default |
| --- | --- | --- |
| `$DesiredMAPSReporting` | Cloud protection membership. Use `Disabled`, `Basic`, or `Advanced`. | `Advanced` |
| `$DesiredSubmitSamplesConsent` | Sample submission behavior. Use `AlwaysPrompt`, `SendSafeSamples`, `NeverSend`, or `SendAllSamples`. | `SendSafeSamples` |
| `$ValidationDelaySeconds` | Wait time before remediation validation. | `3` |

## Intune Deployment

1. Go to Intune admin center.
2. Open **Devices > Manage devices > Scripts and remediations**.
3. Create a new script package.
4. Upload `Detect.ps1` as the detection script.
5. Upload `Remediate.ps1` as the remediation script.
6. Run as system.
7. Run in 64-bit PowerShell.
8. Assign to a pilot group before broad deployment.

## Expected Results

- Detection exits `0` when both cloud protection settings match the desired values.
- Detection exits `1` when remediation should run.
- Remediation exits `0` only after both desired values are confirmed.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Defender-Enable-Cloud-Protection\Detect.log` and `Remediate.log`.
- Confirm Microsoft Defender Antivirus cmdlets are available.
- Check whether Tamper Protection, another policy, security baseline, or GPO controls these settings.
- Review Intune Management Extension logs in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
