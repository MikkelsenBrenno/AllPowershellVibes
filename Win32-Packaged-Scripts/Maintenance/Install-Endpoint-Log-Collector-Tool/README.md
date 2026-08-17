# Install Endpoint Log Collector Tool

## Summary

Installs a small helper script that collects common endpoint troubleshooting logs into a timestamped zip file. This gives technicians a copy-and-customize Win32 package for local support bundles.

## Prerequisites

Package the folder as a Win32 app with the Microsoft Win32 Content Prep Tool. Run install, detection, and uninstall in the system context.

## Customization

Edit the CONFIGURATION sections before packaging.

- `Install.ps1`: Change `$InstallRoot`, `$CollectorScriptName`, and `$Version`.
- `Detect.ps1`: Keep `$ExpectedVersion` aligned with the install script.
- `Collect-EndpointLogs.ps1`: Change `$SourceLogFolders`, `$BundleRoot`, and `$MaxFilesPerSource`.
- `Uninstall.ps1`: Set `$RemoveCollectedLogBundles` only if you want uninstall to delete existing bundles.

## Intune App Commands

Install command: `powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1`

Uninstall command: `powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1`

Detection rule: Use a custom detection script and upload `Detect.ps1`.

## Expected Results

The install script copies `Collect-EndpointLogs.ps1` to ProgramData and writes a version marker. Running the collector creates a zip file under the configured bundle root.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Install-Endpoint-Log-Collector-Tool`. If detection fails, confirm the installed script and marker version under the configured `$InstallRoot`.
