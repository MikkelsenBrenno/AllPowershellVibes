# Install Inventory Collector Template

## Summary

This Win32 packaged script installs, detects, and removes a local PowerShell inventory collector helper that writes a JSON inventory snapshot on demand.

## Files

- `InventoryCollector.ps1` - Payload script copied to the device.
- `Install.ps1` - Copies the payload and writes a version marker.
- `Detect.ps1` - Detects the payload and version marker.
- `Uninstall.ps1` - Removes the configured payload and marker.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ToolRoot` | Folder where the payload is installed. | `C:\ProgramData\IntuneScriptLibrary\Tools\InventoryCollector` |
| `$ToolFileName` | Payload script file name. | `InventoryCollector.ps1` |
| `$PackageVersion` | Version marker written during install. | `1.0.0` |
| `$ExpectedPackageVersion` | Version expected by detection. | `1.0.0` |
| `$InventoryRoot` | Folder where the payload writes inventory output. | `C:\ProgramData\IntuneScriptLibrary\Inventory` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- System install behavior when writing to ProgramData.

## Customization

Replace or extend `InventoryCollector.ps1` with the inventory evidence your technicians need. Keep install and detection versions aligned.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\Inventory-Reporting\Install-Inventory-Collector-Template" -s "Install.ps1" -o ".\PackageOutput"
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

- Install `0` - Collector copied and marker written.
- Install `1` - Collector install failed.
- Detection `0` with STDOUT - Collector and marker are detected.
- Detection `1` - Collector is missing or version mismatch exists.
- Uninstall `0` - Collector and marker are absent.
- Uninstall `1` - Collector removal failed.

## Expected Results

The configured inventory collector exists under `$ToolRoot` and can write a JSON snapshot to `$InventoryRoot`.

## Troubleshooting

- Confirm the payload script exists beside `Install.ps1` before packaging.
- Confirm install and detection use the same version.
- Review script logs and Intune Management Extension logs together.
