# Check Office Update Channel

## Summary

This custom compliance package checks whether Microsoft 365 Apps is using the expected update channel URL.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ExpectedChannelUrl` | Expected Microsoft 365 Apps update channel URL. | Current Channel URL |
| `$TreatMissingOfficeAsCompliant` | Whether devices without Click-to-Run Office should pass. | `$true` |
| `$ChannelRegistryChecks` | Registry paths and values checked in priority order. | Cloud, policy, and Click-to-Run paths |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Custom compliance policy support.
- Microsoft 365 Apps Click-to-Run installed on targeted devices.

## Customization

Change `$ExpectedChannelUrl` to the channel your tenant expects. Keep the registry checks in priority order so policy-managed values win over unmanaged Click-to-Run values.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices that should have Microsoft 365 Apps installed and managed.

## Expected Results

Compliant devices return `OfficeUpdateChannelCompliant` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Office-Update-Channel`.
- Confirm Office has applied the latest policy and update task.
- Confirm the expected URL matches the channel used by your organization.

## Common Failures

- A Cloud Update setting overrides the local policy value.
- Office has not run an update cycle since the channel changed.
