# Export Printer Inventory

## Summary

Exports installed printer details to a local JSON file for support and troubleshooting. The script uses `Get-Printer` when available and can fall back to `Win32_Printer`.

## Prerequisites

Run as system for device-wide printer inventory or as user if you need user-context printer mappings. Confirm the output path is acceptable for your support workflow.

## Customization

Edit the CONFIGURATION section in `Export-Printer-Inventory.ps1`.

- `$OutputRoot`: Folder where the JSON file is written.
- `$OutputFileName`: Name of the inventory file.
- `$IncludeCimFallbackProperties`: Whether to use CIM when `Get-Printer` is unavailable.

## Intune Settings

Upload `Export-Printer-Inventory.ps1` as an Intune platform script. Use 64-bit PowerShell. Choose system or user context based on the printers you need to inspect.

## Expected Results

The script writes `PrinterInventory.json` and logs the printer count. Intune receives exit code 0 when the export succeeds.

## Troubleshooting

Check the local log under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Printer-Inventory`. If no printers appear, rerun in the user context to check per-user printer connections.
