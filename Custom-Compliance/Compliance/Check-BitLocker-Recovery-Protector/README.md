# Check BitLocker Recovery Protector

## Summary

This custom compliance package checks whether the configured BitLocker volume has a recovery password or recovery key protector.

## Files

- `Discover.ps1` - Returns BitLocker recovery protector details.
- `ComplianceRules.json` - Requires a recovery protector to exist.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$MountPoint` | BitLocker volume to check. | `C:` |
| `$AcceptedRecoveryProtectorTypes` | Protector types accepted as recovery protectors. | `RecoveryPassword`, `RecoveryKey` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- BitLocker PowerShell cmdlets.
- System context recommended.

## Customization

Adjust accepted protector types only if your recovery model requires it.

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

The device is compliant when the configured volume has at least one accepted recovery protector.

## Troubleshooting

- Review `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-BitLocker-Recovery-Protector\Discover.log`.
- Confirm BitLocker is enabled on the configured volume.
- Confirm recovery protector escrow and protector creation policy.

## Common Failures

- BitLocker is enabled but no recovery password protector exists.
- The script checks the wrong volume.
- BitLocker cmdlets are unavailable in the selected context.
