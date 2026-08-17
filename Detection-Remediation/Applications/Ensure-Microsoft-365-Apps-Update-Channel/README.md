# Ensure Microsoft 365 Apps Update Channel

## Summary

Detects whether Microsoft 365 Apps Click-to-Run channel values match the expected channel URL and can set them. This is useful when devices drift from Monthly Enterprise, Current Channel, or another managed channel.

## Prerequisites

Run in the system context with 64-bit PowerShell. Confirm the target channel URL from your Microsoft 365 Apps deployment policy before enabling remediation.

## Customization

Edit the CONFIGURATION section in both scripts.

- `$ExpectedChannelUrl` and `$TargetChannelUrl`: Desired channel URL.
- `$ChannelValueNames`: Registry values to compare or set.
- `$TriggerOfficeUpdateAfterChange`: Optionally starts Office update after remediation.
- `$ApplyChannelChange`: Set to `$true` after pilot testing.

## Intune Deployment

Upload `Detect.ps1` and `Remediate.ps1` as an Intune remediation package. Run as system with 64-bit PowerShell.

## Expected Results

Detection exits 0 when the configured Click-to-Run values match the expected channel. Remediation reports intended changes until `$ApplyChannelChange` is enabled.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Microsoft-365-Apps-Update-Channel`. If the channel changes back, review Microsoft 365 Apps policy assignments and Office cloud policy settings.

## Credits

Inspired by public Intune remediation Microsoft 365 Apps update-channel patterns. See `docs/Open-Source-Inspiration-And-Credits.md`.
