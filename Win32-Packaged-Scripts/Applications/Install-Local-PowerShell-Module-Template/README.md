# Install-Local-PowerShell-Module-Template

## Summary

Installs a packaged PowerShell module into the machine-wide PowerShell module path. This template is useful when technicians need to deploy internal helper modules, troubleshooting cmdlets, or script dependencies through Intune Win32 apps.

## Prerequisites

- Package the folder as a Win32 app with the Microsoft Win32 Content Prep Tool.
- Deploy in the system context.
- Replace `Module\ExampleModule` with your real module before packaging.
- Confirm the module name and version do not conflict with existing modules.

## Customization

Edit the CONFIGURATION section near the top of the scripts:

- `$SourceModuleFolderName`: Module folder included under `Module`.
- `$ModuleName`: Installed module name.
- `$ModuleVersion`: Version folder and manifest version expected by detection.
- `$ModuleBaseRoot`: Machine-wide module path.
- `$ExpectedModuleFiles`: Files that must exist after install.
- `$ModuleManifestFileName`: Manifest file used by detection.
- `$RemoveParentModuleFolderIfEmpty`: Removes the parent module folder when no versions remain.

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

- Install exits `0` after expected module files are copied.
- Detection exits `0` and writes STDOUT when the module version and expected files are present.
- Detection exits `1` when the module folder, files, or manifest version are missing.
- Uninstall exits `0` after the configured module version is removed.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Install-Local-PowerShell-Module-Template`.

## Troubleshooting

- If detection fails after install, verify `$ModuleVersion` matches the `.psd1` manifest.
- If module files are missing, confirm `$ExpectedModuleFiles` matches your payload.
- If import behavior differs on 64-bit and 32-bit PowerShell, confirm Intune detection is not running in 32-bit mode.
- Review Intune Management Extension logs and the package logs together.
