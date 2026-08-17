# Install Endpoint Health Snapshot Tool

## Summary

This Win32 packaged script installs, detects, and removes a local PowerShell helper that writes an endpoint health snapshot on demand.

## Files

- `EndpointHealthSnapshot.ps1` - Payload script copied to the device.
- `Install.ps1` - Copies the payload and writes a version marker.
- `Detect.ps1` - Detects the payload and version marker.
- `Uninstall.ps1` - Removes the configured payload and marker.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ToolRoot` | Folder where the payload is installed. | `C:\ProgramData\IntuneScriptLibrary\Tools\EndpointHealthSnapshot` |
| `$ToolFileName` | Payload script file name. | `EndpointHealthSnapshot.ps1` |
| `$PackageVersion` | Version marker written during install. | `1.0.0` |
| `$ExpectedPackageVersion` | Version expected by detection. | `1.0.0` |
| `$ServicesToReport` | Services included by the payload. | IME, Windows Update, BITS |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- System install behavior when writing to ProgramData.

## Customization

Replace or extend `EndpointHealthSnapshot.ps1` with your real endpoint health evidence collection logic.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\Endpoint-Health\Install-Endpoint-Health-Snapshot-Tool" -s "Install.ps1" -o ".\PackageOutput"
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

- Install `0` - Tool copied and marker written.
- Install `1` - Tool install failed.
- Detection `0` with STDOUT - Tool and marker are detected.
- Detection `1` - Tool is missing or version mismatch exists.
- Uninstall `0` - Tool and marker are absent.
- Uninstall `1` - Tool removal failed.

## Expected Results

The configured endpoint health payload exists under `$ToolRoot` and can be run by a technician or scheduled task.

## Troubleshooting

- Confirm the payload script exists beside `Install.ps1` before packaging.
- Confirm install and detection use the same version.
- Review script logs and Intune Management Extension logs together.
