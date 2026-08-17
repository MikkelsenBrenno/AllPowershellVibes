# Install Company Branding Assets

## Summary

This Win32 packaged script installs, detects, and removes local company branding asset files such as a wallpaper image or logo.

## Files

- `Install.ps1` - Copies branding assets and writes a version marker.
- `Detect.ps1` - Detects branding assets and version marker.
- `Uninstall.ps1` - Removes only the configured branding assets and marker.
- Asset files - Add your real image files to this folder before packaging.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$BrandingRoot` | Local folder where assets are installed. | `C:\ProgramData\IntuneScriptLibrary\Branding` |
| `$AssetFileNames` | Files copied from the package folder. | `CompanyWallpaper.jpg`, `CompanyLogo.png` |
| `$BrandingVersion` | Version marker written during install. | `1.0.0` |
| `$ExpectedBrandingVersion` | Version expected by detection. | `1.0.0` |
| `$RemoveBrandingRootWhenEmpty` | Remove the asset folder when empty. | `$true` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- Real branding asset files included in the package folder.

## Customization

Replace the example asset file names with your real wallpaper, logo, or support images. Keep version values aligned between install and detection.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\User-Experience\Install-Company-Branding-Assets" -s "Install.ps1" -o ".\PackageOutput"
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

- Install `0` - Assets copied and marker written.
- Install `1` - Asset install failed.
- Detection `0` with STDOUT - Assets and marker are detected.
- Detection `1` - Assets are missing or version mismatch exists.
- Uninstall `0` - Configured assets are absent.
- Uninstall `1` - Asset removal failed.

## Expected Results

The configured branding files are available under `$BrandingRoot`.

## What Success Looks Like

- Detection writes `Detected. Branding assets version '<version>' are installed.`
- Logs exist under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Install-Company-Branding-Assets`.

## Troubleshooting

- Confirm every asset listed in `$AssetFileNames` exists beside `Install.ps1`.
- Confirm install and detection use the same version.
- Confirm the app runs as System if installing to ProgramData.

## Common Failures

- Asset file names were changed in `Install.ps1` but not in `Detect.ps1`.
- The placeholder image files were not added before packaging.
- Detection version was not updated after replacing assets.
