# Install Portable App Template

## Summary

This Win32 packaged script template installs, detects, and removes a portable application folder copied from a package payload.

## Files

- `Payload` - Replace this folder with the portable app files.
- `Install.ps1` - Copies payload files and writes a version marker.
- `Detect.ps1` - Detects the install folder and version marker.
- `Uninstall.ps1` - Removes the configured install folder.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$PayloadFolderName` | Folder copied from the package. | `Payload` |
| `$InstallRoot` | Destination folder on the device. | `C:\ProgramData\IntuneScriptLibrary\PortableApps\ExamplePortableApp` |
| `$PackageVersion` | Version marker written during install. | `1.0.0` |
| `$ExpectedPackageVersion` | Version expected by detection. | `1.0.0` |
| `$MarkerFileName` | Marker file name. | `portable-app-version.txt` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- Portable app payload files included in the `Payload` folder.

## Customization

Replace the example payload with your portable application files and update `$InstallRoot` and version values.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\Applications\Install-Portable-App-Template" -s "Install.ps1" -o ".\PackageOutput"
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

- Install `0` - Payload copied and marker written.
- Install `1` - Install failed.
- Detection `0` with STDOUT - Portable app is detected.
- Detection `1` - Portable app is missing or version mismatch exists.
- Uninstall `0` - Install folder is absent.
- Uninstall `1` - Removal failed.

## Expected Results

The configured portable app payload exists under `$InstallRoot` and the marker version matches detection.

## Troubleshooting

- Confirm payload files exist inside the `Payload` folder before packaging.
- Confirm install and detection use the same version values.
- Review script logs and Intune Management Extension logs together.
