# Check Feature Update Target Release Policy

## Summary

This custom compliance package checks whether Windows Update for Business target release policy values match the configured expected version.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$WindowsUpdatePolicyPath` | Registry path used for Windows Update policy. | `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate` |
| `$ExpectedTargetReleaseVersionInfo` | Target release version expected on devices. | `REPLACE_WITH_TARGET_VERSION` |
| `$ExpectedProductVersion` | Product version expected on devices. | `Windows 11` |
| `$RequireTargetReleaseVersionEnabled` | Requires `TargetReleaseVersion=1`. | `$true` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Windows Update for Business policy deployed through Intune, GPO, or another channel.

## Customization

Replace `$ExpectedTargetReleaseVersionInfo` with your approved feature update target, such as a tenant-standard release value.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices where feature update target release policy should affect compliance.

## Expected Results

Compliant devices return `FeatureUpdateTargetReleaseCompliant` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Feature-Update-Target-Release-Policy`.
- Confirm policy values are written under HKLM.
- Confirm Intune update rings or feature update policies are assigned to the device.

## Common Failures

- The target release placeholder was not replaced.
- GPO overwrites Intune Windows Update for Business policy.
- The product version does not match the expected Windows generation.
