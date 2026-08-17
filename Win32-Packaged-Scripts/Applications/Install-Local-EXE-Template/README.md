# Install Local EXE Template

## Summary

This Win32 packaged script template installs, detects, and uninstalls an application using a local EXE installer and registry-based detection.

## Files

- `Install.ps1` - Runs the local EXE installer and validates detection.
- `Detect.ps1` - Detects the application by uninstall registry display name.
- `Uninstall.ps1` - Runs a configurable uninstall command and validates removal.
- Installer EXE - Add your real installer file to this folder before packaging.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$InstallerFileName` | EXE installer included in the package folder. | `ExampleSetup.exe` |
| `$InstallerArguments` | Silent install arguments. | `/quiet /norestart` |
| `$ExpectedDisplayNamePattern` | Display name text expected in uninstall registry keys. | `Example Application` |
| `$MinimumDisplayVersion` | Optional minimum version required by detection. | Empty |
| `$UninstallerFilePath` | Local uninstaller path used by `Uninstall.ps1`. | Example path |
| `$UninstallerArguments` | Silent uninstall arguments. | `/quiet /norestart` |
| `$AcceptedSuccessExitCodes` | Installer or uninstaller exit codes treated as success. | `0`, `3010` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Win32 Content Prep Tool.
- PowerShell 5.1.
- A vendor EXE installer that supports silent install and uninstall.

## Customization

Replace the installer file name, arguments, detection display name, and uninstall command with the vendor-specific values before packaging.

## Package Creation

```powershell
IntuneWinAppUtil.exe -c ".\Win32-Packaged-Scripts\Applications\Install-Local-EXE-Template" -s "Install.ps1" -o ".\PackageOutput"
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

- Install `0` - EXE install succeeded.
- Install `3010` - EXE install succeeded and restart is required.
- Install `1` - EXE install failed.
- Detection `0` with STDOUT - Application is detected.
- Detection `1` - Application is missing.
- Uninstall `0` - Application is absent.
- Uninstall `1` - Uninstall failed.

## Expected Results

The configured application is installed and appears in uninstall registry entries matching `$ExpectedDisplayNamePattern`.

## Troubleshooting

- Confirm the EXE installer exists beside `Install.ps1` before packaging.
- Confirm silent install and uninstall switches with vendor documentation.
- Confirm detection display name matches the installed application exactly enough for the wildcard pattern.
- Review script logs and Intune Management Extension logs together.
