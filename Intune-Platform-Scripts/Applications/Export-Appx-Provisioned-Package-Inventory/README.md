# Export Appx Provisioned Package Inventory

## Summary

Exports provisioned AppX package inventory and optional installed package counts to JSON for Business Premium app cleanup and troubleshooting.

## Prerequisites

Run as system with 64-bit PowerShell. AppX cmdlets must be available on the target Windows version.

## Customization

Edit the CONFIGURATION section in `Export-Appx-Provisioned-Package-Inventory.ps1`.

- `$OutputRoot`: Folder where JSON output is written.
- `$OutputFileName`: Output file name.
- `$IncludeInstalledPackageCounts`: Includes installed package counts across users.

## Intune Settings

Upload `Export-Appx-Provisioned-Package-Inventory.ps1` as an Intune platform script. Run as system with 64-bit PowerShell.

## Expected Results

The script writes `AppxProvisionedPackageInventory.json` and exits 0 when export succeeds.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Appx-Provisioned-Package-Inventory`. If inventory is empty, confirm the script is running elevated and AppX cmdlets are present.
