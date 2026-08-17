# Check Local Time Zone

## Summary

This custom compliance package checks whether the local Windows time zone ID matches the expected value.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ExpectedTimeZoneId` | Expected Windows time zone ID. | `W. Europe Standard Time` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Custom compliance policy support.

## Customization

Run `Get-TimeZone -ListAvailable` on a reference device to confirm the exact Windows time zone ID.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices that should use a specific regional time zone.

## Expected Results

Compliant devices return `TimeZoneCompliant` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Local-Time-Zone`.
- Confirm the expected ID is a Windows time zone ID, not an IANA name.

## Common Failures

- The expected time zone string is misspelled.
- Devices are assigned to the wrong regional group.
