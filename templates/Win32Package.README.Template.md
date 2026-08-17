# <Win32 Packaged Script Name>

## Summary

Describe what the packaged PowerShell script installs, uninstalls, and detects.

## Files

- `Install.ps1` - Applies the configuration.
- `Uninstall.ps1` - Removes the configuration.
- `Detect.ps1` - Returns detection state for Intune.

## What To Change First

Open all three scripts and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `<SettingName>` | `<What admins should change>` | `<Default>` |

Confirm `Install.ps1` writes the same location and value that `Detect.ps1` checks. Confirm `Uninstall.ps1` removes only the files, registry keys, or settings owned by this package.

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- Required local permissions for install and uninstall actions.

## Customization

Update the `CONFIGURATION` section in all three scripts before deployment. That section should contain every value technicians are expected to change, such as install paths, registry keys, value names, expected values, URLs, tenant labels, and detection timing.

Keep custom values near the top of each script so admins can review them quickly without reading the full script body.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Install command | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1` |
| Uninstall command | `%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1` |
| Install behavior | `<System or User>` |
| Device restart behavior | `<No specific action unless documented>` |
| Detection rule | Custom detection script |
| Detection script | `Detect.ps1` |
| Run detection as 32-bit on 64-bit clients | `<No when using native HKLM or Program Files paths>` |

## Package Creation

From the folder above this package folder, run:

```powershell
IntuneWinAppUtil.exe -c "<PackageFolder>" -s "Install.ps1" -o ".\PackageOutput"
```

## Intune App Commands

Install command:

```text
%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1
```

Uninstall command:

```text
%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

Detection:

- Use custom detection script.
- Upload `Detect.ps1`.
- For 64-bit registry and file system checks, do not run the detection script as a 32-bit process on 64-bit clients.

## Exit Codes

- Install `0` - Installation completed.
- Install `1` - Installation failed.
- Uninstall `0` - Uninstallation completed.
- Uninstall `1` - Uninstallation failed.
- Detection `0` with STDOUT - App/configuration detected.
- Detection `1` - App/configuration not detected.

## Expected Results

Describe the installed and uninstalled states.

## What Success Looks Like

- Install exits `0` after validating the installed state.
- Detection exits `0` and writes output only when the app/configuration is detected.
- Detection exits `1` when the app/configuration is absent or not at the expected version.
- Uninstall exits `0` after validating the removed state.

## Troubleshooting

- Review script logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\<ScriptPackageName>\Install.log`, `Uninstall.log`, and `Detect.log`.
- Review Intune Management Extension logs.
- Confirm the app install behavior context matches the script requirements.
- Confirm detection checks the same location that install writes to.

## Common Failures

- Install writes one path, but detection checks another path.
- Detection checks a native 64-bit registry or file system path while running in 32-bit mode.
- Uninstall removes a shared parent key or folder instead of only this package's owned content.
- The expected version or marker value was changed in one script but not the others.
