# Create Local Support Info Registry Key

## Summary

This platform script writes local support information to a dedicated HKLM registry key.

## File

- `Create-Local-Support-Info-Registry-Key.ps1`

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$RegistryPath` | Registry key to write. | `HKLM:\SOFTWARE\IntuneScriptLibrary\SupportInfo` |
| `$CompanyName` | IT/support organization name. | `Contoso IT` |
| `$SupportUrl` | Support portal URL. | `https://example.com/support` |
| `$SupportEmail` | Support email address. | `support@example.com` |
| `$SupportPhone` | Support phone number. | `+1 555 0100` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended for HKLM.

## Customization

Replace all placeholder support information before deployment.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Create-Local-Support-Info-Registry-Key.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy as a platform script to devices that should carry local support metadata.

## Exit Codes

- `0` - Support information was written and validated.
- `1` - Support information could not be written.

## Expected Results

The configured registry key contains company support information.

## Troubleshooting

- Review `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Create-Local-Support-Info-Registry-Key\Create-Local-Support-Info-Registry-Key.log`.
- Confirm 64-bit registry view when reading the values.

## Common Failures

- Placeholder support values were not changed.
- A user-context deployment cannot write HKLM.
