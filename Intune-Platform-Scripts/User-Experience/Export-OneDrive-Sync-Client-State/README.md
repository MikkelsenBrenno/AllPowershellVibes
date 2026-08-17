# Export OneDrive Sync Client State

## Summary

Exports OneDrive sync client version and per-profile OneDrive folder signals for Business Premium Known Folder Move and sync troubleshooting.

## Prerequisites

Run as system with 64-bit PowerShell to inspect machine-level OneDrive install paths and local profile folders.

## Customization

Edit the CONFIGURATION section in `Export-OneDrive-Sync-Client-State.ps1`.

- `$OutputRoot`: Folder where JSON output is written.
- `$OutputFileName`: Output file name.
- `$OneDriveExecutableCandidates`: OneDrive executable paths to check.
- `$UserProfileRoot`: User profile root to scan.

## Intune Settings

Upload `Export-OneDrive-Sync-Client-State.ps1` as an Intune platform script. Run as system with 64-bit PowerShell.

## Expected Results

The script writes `OneDriveSyncClientState.json` and exits 0 when export succeeds.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-OneDrive-Sync-Client-State`. If no profile folders are found, confirm local user profiles exist and OneDrive has completed setup.
