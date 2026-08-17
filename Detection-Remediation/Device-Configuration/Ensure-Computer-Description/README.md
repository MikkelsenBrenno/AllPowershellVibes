# Ensure Computer Description

## Summary

This remediation package detects and can set the local computer description shown through LanmanServer metadata.

## Files

- `Detect.ps1` - Checks the current computer description.
- `Remediate.ps1` - Reports or writes the expected computer description.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ExpectedDescription` | Expected computer description. | `Managed by Contoso IT` |
| `$LanmanServerParametersPath` | Registry path for the description value. | LanmanServer parameters path |
| `$DescriptionValueName` | Description registry value name. | `srvcomment` |
| `$ApplyDescription` | Actually write the description. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Replace the Contoso default with your organization name, support label, or asset process text.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy in reporting-only mode first, then enable `$ApplyDescription` after confirming the expected value.

## Exit Codes

- Detection `0` - Computer description matches expected value.
- Detection `1` - Computer description is missing or different.
- Remediation `0` - Description was written or reporting-only success is enabled.
- Remediation `1` - Description remains noncompliant.

## Expected Results

The configured computer description is stored in the LanmanServer parameters registry key.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Computer-Description`.
- Confirm another inventory process is not overwriting the description.

## Common Failures

- `$ApplyDescription` is still disabled.
- The description value is changed by a different management tool.
