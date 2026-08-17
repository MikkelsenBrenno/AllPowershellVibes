# Example: Install File Version Marker

## Summary

This Win32 packaged script example installs, detects, and removes a file-based version marker. It is useful as a simple pattern for packages where detection should check a file and expected version.

## Files

- `Install.ps1` - Creates the marker file.
- `Detect.ps1` - Detects the marker file and expected version.
- `Uninstall.ps1` - Removes the marker file.

## What To Change First

Open all three scripts and review the `CONFIGURATION` section.

| Setting | Description | Default |
| --- | --- | --- |
| `$InstallRoot` | Folder that stores the marker file. | `C:\ProgramData\IntuneScriptLibrary\ExampleFileVersionMarker` |
| `$MarkerFileName` | Marker file name. | `installed-version.txt` |
| `$InstalledVersion` | Version written by install. | `1.0.0` |
| `$ExpectedVersion` | Version expected by detection. | `1.0.0` |
| `$RemoveInstallRootWhenEmpty` | Remove the package folder during uninstall when empty. | `$true` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- System install behavior recommended.

## Customization

Keep the marker path and version values aligned across all three scripts.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\Applications\Example-Install-File-Version-Marker" -s "Install.ps1" -o ".\PackageOutput"
```

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Install command | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1` |
| Uninstall command | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1` |
| Install behavior | System |
| Detection rule | Custom detection script |
| Detection script | `Detect.ps1` |
| Run detection as 32-bit on 64-bit clients | No when using ProgramData or native paths |

## Intune App Commands

Use the install and uninstall commands shown above.

## Exit Codes

- Install `0` - Marker was written and validated.
- Install `1` - Marker could not be written.
- Detection `0` with STDOUT - Marker exists with the expected version.
- Detection `1` - Marker is missing or version does not match.
- Uninstall `0` - Marker was removed or already absent.
- Uninstall `1` - Marker could not be removed.

## Expected Results

The marker file exists after install and is absent after uninstall.

## What Success Looks Like

- Detection writes `Detected. Marker version is '1.0.0'.` when installed.
- Logs exist under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Example-Install-File-Version-Marker`.

## Troubleshooting

- Confirm install and detection use the same path.
- Confirm version values match between `Install.ps1` and `Detect.ps1`.
- Review Intune Management Extension logs.

## Common Failures

- Version was changed in `Install.ps1` but not in `Detect.ps1`.
- Detection runs before install has written the marker.
- Uninstall removes a folder that was reused for other package content.
