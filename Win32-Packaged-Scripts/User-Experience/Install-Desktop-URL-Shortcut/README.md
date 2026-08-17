# Install Desktop URL Shortcut

## Summary

This Win32 packaged script installs, detects, and removes an all-users desktop URL shortcut with a version marker.

## Files

- `Install.ps1` - Creates the URL shortcut and writes a marker.
- `Detect.ps1` - Detects the shortcut URL and marker version.
- `Uninstall.ps1` - Removes the configured shortcut and marker.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ShortcutRoot` | Folder where the shortcut is created. | Public desktop |
| `$ShortcutFileName` | Shortcut display name. | `Company Portal.url` |
| `$ShortcutUrl` | URL opened by the shortcut. | Company Portal URL |
| `$PackageVersion` | Version marker written during install. | `1.0.0` |
| `$ExpectedPackageVersion` | Version expected by detection. | `1.0.0` |
| `$MarkerRoot` | Marker folder used for detection. | `C:\ProgramData\IntuneScriptLibrary\Shortcuts\DesktopUrl` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- System install behavior when writing to the public desktop.

## Customization

Replace `$ShortcutFileName` and `$ShortcutUrl` with the user-facing shortcut your organization needs.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\User-Experience\Install-Desktop-URL-Shortcut" -s "Install.ps1" -o ".\PackageOutput"
```

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Install command | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1` |
| Uninstall command | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1` |
| Install behavior | System |
| Detection rule | Custom detection script |
| Detection script | `Detect.ps1` |
| Run detection as 32-bit on 64-bit clients | No |

## Intune App Commands

Use the install and uninstall commands shown above.

## Exit Codes

- Install `0` - Shortcut and marker were created.
- Install `1` - Shortcut install failed.
- Detection `0` with STDOUT - Shortcut and marker are detected.
- Detection `1` - Shortcut is missing or incorrect.
- Uninstall `0` - Shortcut and marker are absent.
- Uninstall `1` - Removal failed.

## Expected Results

The configured URL shortcut appears on the public desktop and opens the configured URL.

## Troubleshooting

- Confirm the app runs as System when writing to the public desktop.
- Confirm install and detection use the same URL and version values.
- Review script logs and Intune Management Extension logs together.
