# Check Pending Reboot

## Summary

This custom compliance package reports whether Windows has a pending reboot.

## Files

- `Discover.ps1` - Checks common pending reboot locations.
- `ComplianceRules.json` - Requires `PendingReboot = false`.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$CheckComponentBasedServicing` | Check CBS reboot state. | `$true` |
| `$CheckWindowsUpdate` | Check Windows Update reboot state. | `$true` |
| `$CheckPendingFileRenameOperations` | Check pending file rename operations. | `$true` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Disable a check only if your organization intentionally ignores that reboot signal.

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

Devices are compliant when no configured pending reboot signals exist.

## Troubleshooting

- Review `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Pending-Reboot\Discover.log`.
- Check the logged pending reboot reason.
- Restart the device and re-evaluate compliance.

## Common Failures

- Servicing or update reboot state remains after a failed update.
- Pending file rename operations are present from an installer.
