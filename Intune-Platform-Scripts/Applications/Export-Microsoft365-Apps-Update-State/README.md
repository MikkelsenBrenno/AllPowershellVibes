# Export Microsoft365 Apps Update State

## Summary

Exports Microsoft 365 Apps Click-to-Run update channel and version state to JSON for Business Premium app update troubleshooting.

## Prerequisites

Run as system with 64-bit PowerShell. Microsoft 365 Apps must be installed using Click-to-Run for the registry path to exist.

## Customization

Edit the CONFIGURATION section in `Export-Microsoft365-Apps-Update-State.ps1`.

- `$ClickToRunConfigurationPath`: Registry path to inspect.
- `$OutputRoot`: Folder where JSON output is written.
- `$OutputFileName`: Output file name.

## Intune Settings

Upload `Export-Microsoft365-Apps-Update-State.ps1` as an Intune platform script. Run as system with 64-bit PowerShell.

## Expected Results

The script writes `Microsoft365AppsUpdateState.json` and exits 0 when export succeeds.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Microsoft365-Apps-Update-State`. If configuration is missing, confirm Microsoft 365 Apps is installed and managed by Click-to-Run.
