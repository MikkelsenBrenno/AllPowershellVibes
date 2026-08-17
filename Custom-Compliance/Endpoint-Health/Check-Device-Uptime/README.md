# Check Device Uptime

## Summary

This custom compliance package checks whether a device has been running longer than the configured uptime threshold.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$MaximumUptimeDays` | Maximum allowed uptime. | `14` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Custom compliance policy support.

## Customization

Adjust `$MaximumUptimeDays` to match your restart policy.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices where uptime should be visible in compliance reporting.

## Expected Results

Compliant devices return `DeviceUptimeWithinLimit` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Device-Uptime`.
- Confirm the device has not used Fast Startup in a way that changes restart expectations.

## Common Failures

- The uptime threshold is too strict for shared or kiosk devices.
