# Check Minimum Windows Build

## Summary

This custom compliance package checks whether Windows meets a configurable minimum build number.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$MinimumBuildNumber` | Minimum allowed Windows build number. | `22631` |
| `$CurrentVersionRegistryPath` | Registry path used for UBR details. | Windows current version path |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Custom compliance policy support.

## Customization

Update `$MinimumBuildNumber` to match your supported Windows baseline.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to Windows devices where OS build compliance should be visible.

## Expected Results

Compliant devices return `WindowsBuildCompliant` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Minimum-Windows-Build`.
- Confirm the target build matches your Windows servicing baseline.

## Common Failures

- The minimum build is higher than the fleet can currently reach.
- Devices are blocked from receiving feature or quality updates.
