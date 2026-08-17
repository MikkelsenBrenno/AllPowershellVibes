# Install Network Printer

## Summary

This Win32 packaged script installs, detects, and removes a network printer connection.

## Files

- `Install.ps1` - Adds the network printer connection.
- `Detect.ps1` - Detects the printer connection.
- `Uninstall.ps1` - Removes the printer connection.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$PrinterConnectionName` | Printer share path. | `\\printserver\PrinterName` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- Network access to the print server.
- Print driver availability for the target printer.

## Customization

Replace `$PrinterConnectionName` in all three scripts before packaging.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\User-Experience\Install-Network-Printer" -s "Install.ps1" -o ".\PackageOutput"
```

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Install command | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1` |
| Uninstall command | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1` |
| Install behavior | User for user printer connections, System for device-scoped testing |
| Detection rule | Custom detection script |
| Detection script | `Detect.ps1` |
| Run detection as 32-bit on 64-bit clients | No |

## Intune App Commands

Use the install and uninstall commands shown above.

## Exit Codes

- Install `0` - Printer was added and validated.
- Install `1` - Printer could not be added.
- Detection `0` with STDOUT - Printer exists.
- Detection `1` - Printer is missing.
- Uninstall `0` - Printer is absent.
- Uninstall `1` - Printer could not be removed.

## Expected Results

The configured printer connection is available to the intended user or device context.

## What Success Looks Like

- Detection writes `Detected. Printer '<name>' is installed.`
- Logs exist under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Install-Network-Printer`.

## Troubleshooting

- Confirm the print server is reachable.
- Confirm the script context matches the printer scope.
- Confirm driver installation is permitted.

## Common Failures

- The placeholder printer path was not changed.
- The printer is user-scoped but deployed as System.
- Point and Print restrictions block the connection.
