# Ensure Local Time Zone

## Summary

This remediation package detects and can set the local Windows time zone ID.

## Files

- `Detect.ps1` - Checks the current time zone.
- `Remediate.ps1` - Reports or sets the expected time zone.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ExpectedTimeZoneId` | Expected Windows time zone ID. | `W. Europe Standard Time` |
| `$ApplyTimeZone` | Actually set the time zone. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Run `Get-TimeZone -ListAvailable` on a reference device to confirm the exact Windows time zone ID.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy in reporting-only mode first, then enable `$ApplyTimeZone` after confirming target groups.

## Exit Codes

- Detection `0` - Time zone matches expected value.
- Detection `1` - Time zone is different or unknown.
- Remediation `0` - Time zone was set or reporting-only success is enabled.
- Remediation `1` - Time zone remains noncompliant.

## Expected Results

The local Windows time zone ID matches the configured value.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Local-Time-Zone`.
- Confirm the expected ID is a Windows time zone ID.

## Common Failures

- `$ApplyTimeZone` is still disabled.
- The expected time zone string is misspelled.
