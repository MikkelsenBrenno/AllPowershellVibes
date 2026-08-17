# Set Windows Update Active Hours

## Summary

This platform script configures Windows Update active hours using policy registry values.

## File

- `Set-Windows-Update-Active-Hours.ps1`

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ActiveHoursStart` | Start hour, 0 through 23. | `8` |
| `$ActiveHoursEnd` | End hour, 0 through 23. | `17` |
| `$EnableActiveHours` | Enable active-hours policy values. | `$true` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context required for HKLM policy values.

## Customization

Prefer Intune Update CSP settings when available. Use this script when a registry-based example is needed.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Set-Windows-Update-Active-Hours.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to a pilot group and confirm no other update policy conflicts.

## Exit Codes

- `0` - Active hours configured and validated.
- `1` - Active hours could not be configured.

## Expected Results

Windows Update policy values exist under `HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate`.

## Troubleshooting

- Review `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Set-Windows-Update-Active-Hours\Set-Windows-Update-Active-Hours.log`.
- Check for conflicting Intune, GPO, or Autopatch policy.
- Confirm hours use 0 through 23.

## Common Failures

- Another policy overwrites the same registry values.
- Endpoints are managed by Windows Autopatch or Update CSP policies.
