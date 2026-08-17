# Check Windows Update Last Scan Age

## Summary

This custom compliance package checks whether Windows Update has completed a successful scan within the configured number of days.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$MaximumLastScanAgeDays` | Maximum age for the last successful update scan. | `7` |
| `$TreatNeverScannedAsCompliant` | Whether devices with no scan history should pass. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Windows Update client components available.

## Customization

Adjust `$MaximumLastScanAgeDays` for kiosk, offline, or low-connectivity devices.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices that should scan Windows Update regularly.

## Expected Results

Compliant devices return `WindowsUpdateLastScanWithinLimit` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Windows-Update-Last-Scan-Age`.
- Confirm Windows Update service health.
- Confirm update endpoints are reachable.

## Common Failures

- Windows Update service is disabled.
- Network filtering blocks update scan endpoints.
- The device is offline longer than the configured threshold.
