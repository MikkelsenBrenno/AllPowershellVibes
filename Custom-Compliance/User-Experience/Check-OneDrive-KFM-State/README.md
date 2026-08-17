# Check OneDrive KFM State

## Summary

This custom compliance package checks configurable OneDrive Known Folder Move policy values, including silent account configuration and optional tenant ID matching.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$OneDrivePolicyPath` | OneDrive policy registry path. | `HKLM:\SOFTWARE\Policies\Microsoft\OneDrive` |
| `$ExpectedTenantId` | Optional tenant ID expected in the KFM silent opt-in value. | Empty |
| `$RequireSilentAccountConfig` | Requires `SilentAccountConfig=1`. | `$true` |
| `$RequireKfmOptIn` | Requires the KFM silent opt-in value to exist. | `$false` |
| `$KfmOptInValueName` | Registry value used for KFM tenant opt-in. | `KFMSilentOptIn` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- OneDrive policy deployed through Intune, GPO, or another management channel.

## Customization

Set `$ExpectedTenantId` when your organization wants to verify that Known Folder Move points to a specific tenant.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices where OneDrive Known Folder Move policy drift should affect compliance.

## Expected Results

Compliant devices return `OneDriveKfmStateCompliant` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-OneDrive-KFM-State`.
- Confirm policy is written under the same registry hive the script checks.
- Confirm the tenant ID is exact when `$ExpectedTenantId` is configured.

## Common Failures

- The OneDrive policy has not reached the device yet.
- KFM is configured by user context while the compliance script checks HKLM policy.
- Tenant ID was copied with whitespace or braces.
