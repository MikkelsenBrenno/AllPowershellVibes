# Export WinHTTP And Proxy State

## Summary

Exports WinHTTP proxy output and common Internet Settings proxy values to JSON for Business Premium connectivity troubleshooting.

## Prerequisites

Run as system with 64-bit PowerShell for WinHTTP state. Use user context if you specifically need the signed-in user's HKCU proxy values.

## Customization

Edit the CONFIGURATION section in `Export-WinHTTP-And-Proxy-State.ps1`.

- `$OutputRoot`: Folder where JSON output is written.
- `$OutputFileName`: Output file name.
- `$InternetSettingsPath`: User proxy registry path to inspect.

## Intune Settings

Upload `Export-WinHTTP-And-Proxy-State.ps1` as an Intune platform script. Run as system with 64-bit PowerShell unless user proxy state is the target.

## Expected Results

The script writes `WinHTTPAndProxyState.json` and exits 0 when export succeeds.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-WinHTTP-And-Proxy-State`. If HKCU values are empty under system context, rerun in user context for user-specific proxy settings.
