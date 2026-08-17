# Check SecureBoot And TPM

## Summary

This custom compliance package reports Secure Boot and TPM readiness.

## Files

- `Discover.ps1` - Returns Secure Boot and TPM readiness as compressed JSON.
- `ComplianceRules.json` - Requires `HardwareSecurityCompliant = true`.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$RequireSecureBoot` | Require Secure Boot to be enabled. | `$true` |
| `$RequireTpmReady` | Require TPM to be present, enabled, activated, and owned. | `$true` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- UEFI firmware for Secure Boot checks.
- System context recommended.

## Customization

Disable a requirement only when your hardware policy allows it.

## JSON Output

The script returns one compressed JSON object with Secure Boot and TPM properties.

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

Devices are compliant when required Secure Boot and TPM checks pass.

## Troubleshooting

- Review `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-SecureBoot-And-TPM\Discover.log`.
- Confirm the device supports UEFI Secure Boot.
- Confirm TPM is enabled and activated in firmware.

## Common Failures

- Secure Boot is unsupported or disabled.
- TPM ownership has not completed.
- The check runs on hardware or virtual machines without Secure Boot support.
