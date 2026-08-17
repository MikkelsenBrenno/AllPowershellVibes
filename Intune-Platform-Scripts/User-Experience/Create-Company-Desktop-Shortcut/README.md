# Create Company Desktop Shortcut

## Summary

This platform script creates or updates a URL shortcut on the public desktop.

## File

- `Create-Company-Desktop-Shortcut.ps1`

## What To Change First

Open the script and review the `CONFIGURATION` section.

| Setting | Description | Default |
| --- | --- | --- |
| `$ShortcutName` | Display name of the shortcut file. | `Company Support Portal` |
| `$ShortcutUrl` | URL opened by the shortcut. | `https://example.com/support` |
| `$ShortcutFolder` | Folder where the shortcut is created. | Public desktop |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Intune Management Extension installed.
- PowerShell 5.1.
- System context recommended when writing to the public desktop.

## Customization

Keep the shortcut name, URL, and destination folder in the `CONFIGURATION` section.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Create-Company-Desktop-Shortcut.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | No unless your customization requires it |

## Intune Deployment

1. Upload `Create-Company-Desktop-Shortcut.ps1` as a platform script.
2. Assign to a pilot group.
3. Confirm the shortcut appears on the public desktop.

## Exit Codes

- `0` - Shortcut exists and points to the expected URL.
- `1` - Shortcut could not be created or validated.

## Expected Results

The configured `.url` file exists in the configured shortcut folder and opens the configured URL.

## What Success Looks Like

- Script exits `0`.
- Log shows the shortcut path and URL.
- Users see the shortcut after desktop refresh or next sign-in.

## Troubleshooting

- Review `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Create-Company-Desktop-Shortcut\Create-Company-Desktop-Shortcut.log`.
- Confirm the URL starts with `http://` or `https://`.
- Confirm system context has permission to write to the target folder.

## Common Failures

- The URL placeholder was not changed.
- A user-context deployment tries to write to a protected shared desktop folder.
- The shortcut name contains characters that are invalid for filenames.
