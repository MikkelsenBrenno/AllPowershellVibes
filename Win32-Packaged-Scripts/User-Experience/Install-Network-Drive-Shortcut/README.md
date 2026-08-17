# Install Network Drive Shortcut

## Summary

This Win32 packaged script installs, detects, and removes a shortcut to a network share.

## Files

- `Install.ps1` - Creates the shortcut.
- `Detect.ps1` - Detects the shortcut and target path.
- `Uninstall.ps1` - Removes the shortcut.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ShortcutFolder` | Folder where the shortcut is created. | Public desktop |
| `$ShortcutName` | Shortcut file name. | `Contoso Share.lnk` |
| `$TargetPath` | UNC path opened by the shortcut. | `\\fileserver\Share` |
| `$Description` | Shortcut description. | `Open the Contoso network share` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- Network access to the UNC path.

## Customization

Replace `$TargetPath`, `$ShortcutName`, and `$Description` in all scripts before packaging.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\User-Experience\Install-Network-Drive-Shortcut" -s "Install.ps1" -o ".\PackageOutput"
```

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Install command | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1` |
| Uninstall command | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1` |
| Install behavior | System for public desktop, User for user profile locations |
| Detection rule | Custom detection script |
| Detection script | `Detect.ps1` |
| Run detection as 32-bit on 64-bit clients | No |

## Intune App Commands

Use the install and uninstall commands shown above.

## Exit Codes

- Install `0` - Shortcut was created and validated.
- Install `1` - Shortcut could not be created.
- Detection `0` with STDOUT - Shortcut exists with the expected target.
- Detection `1` - Shortcut is missing or incorrect.
- Uninstall `0` - Shortcut is absent.
- Uninstall `1` - Shortcut could not be removed.

## Expected Results

The shortcut opens the configured network share.

## What Success Looks Like

- Detection writes `Detected. Shortcut '<path>' points to '<target>'.`
- Logs exist under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Install-Network-Drive-Shortcut`.

## Troubleshooting

- Confirm the shortcut folder exists or can be created.
- Confirm the UNC path is reachable by target users.
- Confirm install behavior matches shortcut location.

## Common Failures

- The placeholder UNC path was not changed.
- The shortcut is created on the public desktop but detection runs in a different context.
