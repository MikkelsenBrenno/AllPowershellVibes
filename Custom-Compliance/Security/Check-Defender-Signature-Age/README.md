# Check Defender Signature Age

## Summary

This custom compliance package reports whether Microsoft Defender Antivirus signatures are newer than a configured threshold.

## Files

- `Discover.ps1` - Returns Defender signature age as compressed JSON.
- `ComplianceRules.json` - Requires `DefenderSignatureFresh = true`.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$MaximumSignatureAgeDays` | Maximum allowed signature age in days. | `3` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Defender Antivirus available.
- PowerShell 5.1.
- System context recommended.

## Customization

Set the age threshold to match your update cadence.

## JSON Output

The discovery script returns one compressed JSON object.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Upload the discovery script and rules file to a custom compliance policy.

## Expected Results

Devices are compliant when Defender signatures are not older than the threshold.

## Troubleshooting

- Review `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Defender-Signature-Age\Discover.log`.
- Confirm Defender Antivirus is active or available.
- Confirm the device can reach security intelligence update sources.

## Common Failures

- Third-party antivirus disables Defender status reporting.
- Network restrictions block security intelligence updates.
