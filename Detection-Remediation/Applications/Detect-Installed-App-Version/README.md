# Detect Installed App Version

## Summary

This remediation package detects whether an installed application meets a configured minimum version. Remediation is reporting-only so application updates can be handled by Intune app deployment.

## Files

- `Detect.ps1` - Searches uninstall registry keys and compares versions.
- `Remediate.ps1` - Reports that an app deployment or update is required.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$AppDisplayNamePattern` | App display name pattern. Wildcards are supported. | `Google Chrome*` |
| `$MinimumVersion` | Minimum acceptable app version. | `120.0.0.0` |
| `$UninstallRegistryPaths` | Registry locations to search. | HKLM 64-bit and 32-bit uninstall keys |
| `$ExitZeroInReportingOnlyMode` | Exit `0` even though the app still needs action. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended for machine-wide app inventory.
- 64-bit PowerShell recommended so native HKLM paths are visible.

## Customization

Use the exact app display name pattern and minimum version required by your environment.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to a pilot group first and compare results with Intune app inventory.

## Exit Codes

- Detection `0` - App is installed and meets the minimum version.
- Detection `1` - App is missing, old, or cannot be validated.
- Remediation `1` - Reporting-only action remains required by default.

## Expected Results

Devices with an app below the minimum version are reported for update.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Detect-Installed-App-Version`.
- Confirm the app has a `DisplayVersion` that can be parsed as a version.
- Confirm the display name pattern matches the installed app.

## Common Failures

- Vendor display versions contain text that cannot be parsed as `[version]`.
- Detection is run in 32-bit PowerShell and misses native 64-bit uninstall keys.
- The app is installed per-user but detection is running as system.
