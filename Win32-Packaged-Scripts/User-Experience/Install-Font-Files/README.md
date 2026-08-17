# Install Font Files

## Summary

This Win32 packaged script installs one or more font files by copying them to the Windows Fonts folder and creating matching registry entries.

## Files

- `Install.ps1` - Installs font files and registry entries.
- `Detect.ps1` - Detects font files and registry entries.
- `Uninstall.ps1` - Removes font files and registry entries.
- Font files - Add your `.ttf` or `.otf` files to this same folder before packaging.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$FontFiles` | File names and registry display names to install. | `ExampleFont.ttf` |
| `$FontsFolder` | Destination folder. | `%WINDIR%\Fonts` |
| `$FontRegistryPath` | Font registry path. | `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- Font files included in the package folder.
- System install behavior recommended.

## Customization

Replace `ExampleFont.ttf` with your real font file names and update the registry display names to match the font family.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\User-Experience\Install-Font-Files" -s "Install.ps1" -o ".\PackageOutput"
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

- Install `0` - Fonts were copied and validated.
- Install `1` - One or more fonts could not be installed.
- Detection `0` with STDOUT - Fonts are installed.
- Detection `1` - One or more fonts are missing.
- Uninstall `0` - Fonts were removed or already absent.
- Uninstall `1` - One or more fonts could not be removed.

## Expected Results

The configured fonts are available from the Windows Fonts folder and can be detected by Intune.

## What Success Looks Like

- Detection writes `Detected. Installed <n> font file(s).`
- Logs exist under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Install-Font-Files`.

## Troubleshooting

- Confirm every font listed in `$FontFiles` exists beside `Install.ps1`.
- Confirm the app runs as System.
- Restart the target app if it does not immediately see newly installed fonts.

## Common Failures

- Font file names were changed in `Install.ps1` but not in `Detect.ps1`.
- A registry display name was mistyped.
- The font file is locked during uninstall.
