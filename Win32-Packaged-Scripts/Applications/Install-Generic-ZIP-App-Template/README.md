# Install Generic ZIP App Template

## Summary

Provides a copy-and-customize Win32 template for applications delivered as a ZIP archive. The install script extracts the archive to a configurable folder and writes a version marker for detection.

## Prerequisites

Add your real ZIP archive to the package folder and update the script configuration before packaging with the Microsoft Win32 Content Prep Tool.

## Customization

Edit the CONFIGURATION sections before packaging.

- `Install.ps1`: Change `$ArchiveFileName`, `$InstallRoot`, `$Version`, and `$RemoveExistingInstallRootBeforeExtract`.
- `Detect.ps1`: Keep `$ExpectedVersion` aligned with install and optionally add `$RequiredFileRelativePaths`.
- `Uninstall.ps1`: Change `$InstallRoot` and customize `$KeepUserDataPaths` notes if needed.

## Intune App Commands

Install command: `powershell.exe -ExecutionPolicy Bypass -File .\Install.ps1`

Uninstall command: `powershell.exe -ExecutionPolicy Bypass -File .\Uninstall.ps1`

Detection rule: Use a custom detection script and upload `Detect.ps1`.

## Expected Results

The install script expands the ZIP payload, writes the marker file, and exits 0. Detection exits 0 only when the install root, marker version, and required files match.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Install-Generic-ZIP-App-Template`. If install fails, confirm the ZIP file name matches `$ArchiveFileName` and that the Win32 package includes the archive.
