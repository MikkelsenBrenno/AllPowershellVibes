# Check Windows Activation Status

## Summary

This custom compliance package checks whether Windows reports an activated license status through the Software Licensing WMI provider.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$WindowsProductNamePattern` | Product name filter. | `Windows*` |
| `$LicensedStatusCode` | SoftwareLicensingProduct code that means licensed. | `1` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Software Licensing WMI provider available.

## Customization

Most tenants can use the defaults. Adjust the product name pattern only if your fleet reports licensing names differently.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to Windows devices where activation state should be monitored.

## Expected Results

Compliant devices return `WindowsActivated` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Windows-Activation-Status`.
- Run `slmgr /dlv` locally for deeper activation details.
- Confirm the device can reach activation services or KMS.

## Common Failures

- Activation is still in grace or notification mode.
- The device cannot reach KMS or subscription activation services.
