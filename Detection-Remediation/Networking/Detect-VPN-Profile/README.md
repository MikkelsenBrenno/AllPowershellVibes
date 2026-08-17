# Detect VPN Profile

## Summary

This remediation package detects whether a configured VPN profile exists and reports when it is missing.

## Files

- `Detect.ps1` - Checks for the VPN profile.
- `Remediate.ps1` - Reports that the VPN profile is missing.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$VpnConnectionName` | VPN profile name. | `Contoso VPN` |
| `$CheckAllUserConnection` | Check all-user VPN profiles. | `$true` |
| `$ExitZeroInReportingOnlyMode` | Exit successfully when only reporting. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- VPN client/profile support installed.

## Customization

Set `$CheckAllUserConnection` to match whether your VPN profile is deployed per-device or per-user.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No for all-user VPN profiles |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices or users that should receive the VPN profile.

## Exit Codes

- Detection `0` - VPN profile exists.
- Detection `1` - VPN profile is missing.
- Remediation `0` - Reporting-only success is enabled.
- Remediation `1` - VPN profile remains missing.

## Expected Results

Missing VPN profiles are visible in remediation reporting.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Detect-VPN-Profile`.
- Confirm profile scope and script context match.
- Confirm the Intune VPN profile assignment includes the target.

## Common Failures

- The script checks all-user profiles while the VPN is user-scoped.
- The VPN profile display name does not match exactly.
