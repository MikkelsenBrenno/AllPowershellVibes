# Install Start Menu Support Shortcut

## Summary

This Win32 packaged script installs, detects, and removes a Start Menu URL shortcut that points users to an IT support page, portal, ticket form, or knowledge base.

## Files

- `Install.ps1` - Creates the URL shortcut and writes a version marker.
- `Detect.ps1` - Detects the shortcut, URL, and version marker.
- `Uninstall.ps1` - Removes only the configured shortcut and marker.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ShortcutRoot` | Start Menu folder where the shortcut is created. | `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Company` |
| `$ShortcutFileName` | Shortcut display name. | `Contact IT Support.url` |
| `$ShortcutUrl` | Target URL for the support shortcut. | `https://support.contoso.example` |
| `$ShortcutIconFile` | Optional icon path for the URL shortcut. | Empty |
| `$PackageVersion` | Version marker written during install. | `1.0.0` |
| `$ExpectedPackageVersion` | Version expected by detection. | `1.0.0` |
| `$MarkerRoot` | Folder where the detection marker is written. | `C:\ProgramData\IntuneScriptLibrary\Shortcuts\StartMenuSupport` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- A support URL approved for your organization.

## Customization

Replace `$ShortcutUrl`, `$ShortcutFileName`, and `$ShortcutRoot` with your tenant values. Keep `$PackageVersion` and `$ExpectedPackageVersion` aligned whenever you change the shortcut.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\User-Experience\Install-Start-Menu-Support-Shortcut" -s "Install.ps1" -o ".\PackageOutput"
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
- Detection `0` with STDOUT - Shortcut URL and marker match.
- Detection `1` - Shortcut is missing, URL mismatch exists, or marker mismatch exists.
- Uninstall `0` - Configured shortcut and marker are absent.
- Uninstall `1` - Shortcut removal failed.

## Expected Results

The configured shortcut appears in the Start Menu folder and opens the configured support URL.

## What Success Looks Like

- Detection writes `Detected. Support shortcut version '<version>' is installed.`
- Logs exist under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Install-Start-Menu-Support-Shortcut`.

## Troubleshooting

- Confirm `$ShortcutUrl` is reachable from managed devices.
- Confirm install and detection use the same URL and version values.
- Confirm the app runs as System if installing to ProgramData and the all-users Start Menu.
- Review script logs and Intune Management Extension logs together.

## Common Failures

- Detection URL was not updated after changing `Install.ps1`.
- The Start Menu folder is managed by another baseline or image process.
- An icon path was configured but points to a file that does not exist on the endpoint.
