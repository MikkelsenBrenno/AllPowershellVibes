# Check Required App Installed

## Summary

This custom compliance package checks whether a required application is installed by searching common machine-wide uninstall registry locations.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ApplicationDisplayNamePattern` | Display name text to search for. | `Company Portal` |
| `$MinimumDisplayVersion` | Optional minimum version requirement. Empty skips version comparison. | Empty |
| `$UninstallRegistryPaths` | Registry paths to inspect. | HKLM uninstall paths |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Application must register in uninstall registry keys.

## Customization

Replace `$ApplicationDisplayNamePattern` with the application your organization requires. Add `$MinimumDisplayVersion` only when version comparison is reliable.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices where application presence should affect compliance.

## Expected Results

Compliant devices return `RequiredAppInstalled` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Required-App-Installed`.
- Confirm the app display name is registered under HKLM uninstall keys.
- Adjust the display name pattern for language, channel, or vendor differences.

## Common Failures

- The app is per-user and does not appear in HKLM uninstall paths.
- Version strings are not valid PowerShell `[version]` values.
- The display name differs between architectures or install channels.
