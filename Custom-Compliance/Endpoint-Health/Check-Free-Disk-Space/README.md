# Check Free Disk Space

## Summary

This custom compliance package reports whether a configurable local drive has enough free disk space.

## Files

- `Discover.ps1` - Returns compressed JSON with free-space values.
- `ComplianceRules.json` - Requires the drive to meet the configured free-space policy.

## What To Change First

Open `Discover.ps1` and review the `CONFIGURATION` section.

| Setting | Description | Default |
| --- | --- | --- |
| `$DriveLetter` | Drive letter to evaluate. | `C` |
| `$MinimumFreeSpacePercent` | Required free-space percentage. | `15` |
| `$MinimumFreeSpaceGB` | Required free-space amount in GB. | `10` |

Update `ComplianceRules.json` if you change the threshold values in the script.

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Custom compliance policy support for the target platform.
- PowerShell 5.1.
- System context recommended for consistent device inventory.

## Customization

Keep threshold values in the `CONFIGURATION` section so technicians can see them immediately.

## JSON Output

Example output:

```json
{"DriveLetter":"C:","FreeSpaceCompliant":true,"FreeSpacePercent":42,"FreeSpaceGB":128,"TotalSpaceGB":256}
```

The discovery script writes only compressed JSON to STDOUT.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

1. Upload `Discover.ps1` as a custom compliance discovery script.
2. Upload `ComplianceRules.json` in the compliance policy.
3. Assign to a pilot group.

## Expected Results

The device is compliant when both free-space thresholds are met.

## What Success Looks Like

- `Discover.ps1` exits `0`.
- STDOUT contains one compressed JSON object.
- Compliance reports show `FreeSpaceCompliant = true`.

## Troubleshooting

- Review `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Free-Disk-Space\Discover.log`.
- Confirm `ComplianceRules.json` threshold values match the script.
- Run `Discover.ps1` locally and validate the JSON output.

## Common Failures

- The drive letter does not exist on the target device.
- The script and JSON rule thresholds were changed in only one file.
- Extra output was added to the discovery script before the JSON result.
