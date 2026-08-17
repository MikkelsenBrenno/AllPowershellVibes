# Remove Company Desktop Shortcut

## Summary

This platform script removes a configurable shortcut from a configurable desktop folder.

## File

- `Remove-Company-Desktop-Shortcut.ps1`

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ShortcutName` | Shortcut display name without extension. | `Company Support Portal` |
| `$ShortcutFolder` | Folder containing the shortcut. | Public desktop |
| `$ShortcutExtension` | Shortcut extension. | `.url` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended when removing from the public desktop.

## Customization

Use the same shortcut name and folder as the script that created the shortcut.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Remove-Company-Desktop-Shortcut.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | No unless your customization requires it |

## Intune Deployment

Upload the script as a platform script and assign it to devices that should no longer have the shortcut.

## Exit Codes

- `0` - Shortcut is absent.
- `1` - Shortcut could not be removed.

## Expected Results

The configured shortcut is removed from the configured folder.

## Troubleshooting

- Review `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Remove-Company-Desktop-Shortcut\Remove-Company-Desktop-Shortcut.log`.
- Confirm the shortcut name and extension match the file on disk.
- Confirm the script context can delete from the configured folder.

## Common Failures

- The shortcut was created in a user desktop but removal checks the public desktop.
- The shortcut uses `.lnk` while the script expects `.url`.
