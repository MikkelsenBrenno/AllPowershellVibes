# Install-Local-Configuration-Files

## Summary

Installs local configuration files from a packaged `Payload` folder to a configurable device path. The package writes a versioned marker file so Intune custom detection can verify the exact payload version.

## Prerequisites

- Package the folder as a Win32 app with the Microsoft Win32 Content Prep Tool.
- Deploy in the system context.
- Replace the sample files in `Payload` with your real configuration files before packaging.
- Confirm the destination path is dedicated to this package before enabling uninstall cleanup.

## Customization

Edit the CONFIGURATION section near the top of the scripts:

- `$SourcePayloadFolderName`: Payload folder included in the Win32 package.
- `$DestinationRoot`: Destination folder on the device.
- `$PackageVersion`: Version written to the detection marker and expected by detection.
- `$DetectionMarkerFileName`: Marker file used by detection.
- `$ExpectedFileRelativePaths`: Files that must exist after install.
- `$RemoveDestinationRoot`: Controls whether uninstall removes the full destination folder.

## Intune App Configuration

Program install command:

```text
%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
```

Program uninstall command:

```text
%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

Detection rules:

1. Choose **Use a custom detection script**.
2. Upload `Detect.ps1`.
3. Set **Run script as 32-bit process on 64-bit clients** to **No**.
4. Set signature enforcement according to your organization's signing policy.

## Expected Results

- Install exits `0` after the payload files and marker are written.
- Detection exits `0` and writes STDOUT when the expected version and files are present.
- Detection exits `1` when the marker, version, or expected files are missing.
- Uninstall exits `0` after the destination folder or marker is removed.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Install-Local-Configuration-Files`.

## Troubleshooting

- If detection fails after install, verify `$PackageVersion` matches in `Install.ps1` and `Detect.ps1`.
- If files are missing, confirm `$ExpectedFileRelativePaths` matches the `Payload` folder contents.
- If uninstall removes too much, set `$RemoveDestinationRoot` to `$false` or choose a more dedicated destination.
- Review Intune Management Extension logs and the package logs together.
