# Export Firewall Profile State

## Summary

Exports Windows Firewall profile and active network connection profile state to JSON for Business Premium troubleshooting.

## Prerequisites

Run as system with 64-bit PowerShell. Network and firewall cmdlets should be available on supported Windows client versions.

## Customization

Edit the CONFIGURATION section in `Export-Firewall-Profile-State.ps1`.

- `$OutputRoot`: Folder where JSON output is written.
- `$OutputFileName`: Output file name.

## Intune Settings

Upload `Export-Firewall-Profile-State.ps1` as an Intune platform script. Run as system with 64-bit PowerShell.

## Expected Results

The script writes `FirewallProfileState.json` and exits 0 when export succeeds.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Firewall-Profile-State`. If firewall data is empty, confirm the NetSecurity module is available.
