# Ensure SMBv1 Disabled

## Summary

This remediation package detects whether SMBv1 is enabled and can disable it after an explicit safety switch is enabled.

## Files

- `Detect.ps1` - Checks the SMB1 optional Windows feature state.
- `Remediate.ps1` - Reports or disables SMBv1.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$FeatureName` | Optional feature name. | `SMB1Protocol` |
| `$TreatMissingFeatureAsCompliant` | Treat missing feature data as compliant. | `$true` |
| `$DisableSmb1` | Actually disable SMBv1. | `$false` |
| `$NoRestart` | Suppress automatic restart. | `$true` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.
- Approval for legacy SMB impact.

## Customization

Confirm no approved legacy SMBv1 dependency exists before enabling `$DisableSmb1`.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy in reporting-only mode first, then enable `$DisableSmb1` after pilot validation.

## Exit Codes

- Detection `0` - SMBv1 is disabled or absent.
- Detection `1` - SMBv1 is enabled or could not be checked.
- Remediation `0` - SMBv1 is disabled or reporting-only success is enabled.
- Remediation `1` - SMBv1 remains enabled or remediation is disabled.

## Expected Results

The SMB1 optional Windows feature is not enabled.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-SMBv1-Disabled`.
- Run `Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol` locally.
- Plan a restart if Windows reports one is required.

## Common Failures

- `$DisableSmb1` is still disabled.
- Legacy applications or appliances require SMBv1.
- A restart is required before the final state is fully applied.
