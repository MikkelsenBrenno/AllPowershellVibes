# Repair Windows Time Sync

## Summary

This remediation package detects Windows Time service issues and can start the service and request a time resync.

## Files

- `Detect.ps1` - Checks Windows Time service and source.
- `Remediate.ps1` - Starts Windows Time and optionally runs `w32tm /resync`.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ServiceName` | Windows Time service name. | `W32Time` |
| `$AllowLocalCmosClockSource` | Allow Local CMOS Clock as a time source. | `$false` |
| `$StartupType` | Startup type set during remediation. | `Automatic` |
| `$RunResync` | Run `w32tm /resync /force`. | `$true` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

If your environment intentionally uses a local time source, set `$AllowLocalCmosClockSource` to `$true`.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices with time drift, authentication failures, or stale time sync alerts.

## Exit Codes

- Detection `0` - Time service appears healthy.
- Detection `1` - Time service needs attention.
- Remediation `0` - Service was started and validated.
- Remediation `1` - Service could not be repaired.

## Expected Results

The Windows Time service is running and the device is no longer using an unexpected local source.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Repair-Windows-Time-Sync`.
- Run `w32tm /query /status` locally for detailed state.

## Common Failures

- Network or domain policy prevents time synchronization.
- The device cannot reach the configured NTP source.
