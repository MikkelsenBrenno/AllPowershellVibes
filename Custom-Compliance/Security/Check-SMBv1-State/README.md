# Check SMBv1 State

## Summary

This custom compliance package checks whether the SMBv1 optional Windows feature is disabled.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$FeatureName` | Optional feature name to inspect. | `SMB1Protocol` |
| `$TreatMissingFeatureAsCompliant` | Whether a missing feature object should pass. | `$true` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- DISM optional feature cmdlets available.

## Customization

Most tenants can use the default feature name. Change `$TreatMissingFeatureAsCompliant` if missing feature data should be investigated.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to Windows devices where legacy SMBv1 should not be enabled.

## Expected Results

Compliant devices return `SMBv1Disabled` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-SMBv1-State`.
- Run `Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol` locally.

## Common Failures

- Legacy file shares or applications require SMBv1.
- The feature was enabled by a legacy image or application installer.
