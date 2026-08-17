# Export Defender For Business Preferences

## Summary

Exports local Microsoft Defender preferences and status values that are useful in Microsoft 365 Business Premium and Defender for Business troubleshooting.

## Prerequisites

Run as system with 64-bit PowerShell. Defender PowerShell cmdlets must be available on the target device.

## Customization

Edit the CONFIGURATION section in `Export-Defender-For-Business-Preferences.ps1`.

- `$OutputRoot`: Folder where JSON output is written.
- `$OutputFileName`: Output file name.
- `$PreferencePropertyNames`: Defender preference properties to include.

## Intune Settings

Upload `Export-Defender-For-Business-Preferences.ps1` as an Intune platform script. Run as system with 64-bit PowerShell.

## Expected Results

The script writes `DefenderForBusinessPreferences.json` and exits 0 when export succeeds.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Defender-For-Business-Preferences`. If cmdlets are unavailable, confirm Microsoft Defender Antivirus is installed and not removed by another security product.
