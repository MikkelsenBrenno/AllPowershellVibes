# Install Local MSI Template

## Summary

This Win32 packaged script template installs, detects, and uninstalls a local MSI included in the package folder.

## Files

- `Install.ps1` - Installs the MSI and validates the product code.
- `Detect.ps1` - Detects the MSI product code.
- `Uninstall.ps1` - Uninstalls the MSI product code.
- MSI file - Add your real `.msi` file to this folder before packaging.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$MsiFileName` | MSI file included in the package folder. | `ExampleInstaller.msi` |
| `$ProductCode` | MSI product code GUID. | Placeholder GUID |
| `$AdditionalMsiArguments` | Extra msiexec arguments. | `/qn /norestart` |
| `$AcceptedSuccessExitCodes` | Exit codes treated as success. | `0`, `3010` for install |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- The real MSI copied into this package folder.
- Product code confirmed from the MSI vendor or install data.

## Customization

Replace `$MsiFileName` and `$ProductCode` in all scripts. Add vendor-required properties to `$AdditionalMsiArguments`.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\Applications\Install-Local-MSI-Template" -s "Install.ps1" -o ".\PackageOutput"
```

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Install command | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1` |
| Uninstall command | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1` |
| Install behavior | System |
| Device restart behavior | Determine behavior based on return codes |
| Detection rule | Custom detection script |
| Detection script | `Detect.ps1` |
| Run detection as 32-bit on 64-bit clients | No |

## Intune App Commands

Use the install and uninstall commands shown above.

## Exit Codes

- Install `0` - MSI installed.
- Install `3010` - MSI installed and restart is required.
- Install `1` - MSI install failed.
- Detection `0` with STDOUT - MSI product is detected.
- Detection `1` - MSI product is missing.
- Uninstall `0` - MSI uninstalled.
- Uninstall `1605` - Product is already absent.
- Uninstall `3010` - MSI uninstalled and restart is required.
- Uninstall `1` - MSI uninstall failed.

## Expected Results

The MSI product code is present after install and absent after uninstall.

## What Success Looks Like

- Detection writes `Detected. MSI product '<ProductCode>' is installed.`
- MSI logs are written under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Install-Local-MSI-Template`.

## Troubleshooting

- Confirm the product code is correct.
- Review the MSI verbose log in the package log folder.
- Confirm vendor MSI properties are included in `$AdditionalMsiArguments`.

## Common Failures

- Placeholder MSI file name or product code was not changed.
- The MSI requires vendor-specific properties.
- Detection checks the wrong product code.
