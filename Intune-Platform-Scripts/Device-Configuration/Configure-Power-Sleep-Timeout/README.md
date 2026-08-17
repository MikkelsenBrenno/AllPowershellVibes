# Configure Power Sleep Timeout

## Summary

This platform script configures AC and DC Windows sleep timeout values.

## File

- `Configure-Power-Sleep-Timeout.ps1`

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$StandbyTimeoutACMinutes` | Sleep timeout while plugged in. Use `0` for never. | `0` |
| `$StandbyTimeoutDCMinutes` | Sleep timeout on battery. Use `0` for never. | `30` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Use values that match your device class and energy policy.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Configure-Power-Sleep-Timeout.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to a pilot group and confirm power settings on laptops and desktops.

## Exit Codes

- `0` - Timeout values were configured.
- `1` - Configuration failed.

## Expected Results

The active power scheme uses the configured standby timeout values.

## Troubleshooting

- Review `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Configure-Power-Sleep-Timeout\Configure-Power-Sleep-Timeout.log`.
- Confirm another power policy is not overriding the setting.
- Run `powercfg /query` locally for deeper troubleshooting.

## Common Failures

- A device configuration profile controls the same power setting.
- Values are set for laptops but assigned broadly to desktops.
