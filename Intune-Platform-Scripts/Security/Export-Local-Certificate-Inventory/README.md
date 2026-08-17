# Export Local Certificate Inventory

## Summary

Exports local machine certificate inventory to JSON and marks certificates that are expired or expiring soon. This gives support teams a quick view of certificate state without exposing private key material.

## Prerequisites

Run in the system context with 64-bit PowerShell. Confirm which certificate stores should be inventoried before assigning broadly.

## Customization

Edit the CONFIGURATION section in `Export-Local-Certificate-Inventory.ps1`.

- `$CertificateStorePaths`: Certificate stores to scan.
- `$ExpiringWithinDays`: Threshold for the `ExpiresWithinDays` flag.
- `$OutputRoot`: Folder where the JSON file is written.
- `$OutputFileName`: Inventory file name.

## Intune Settings

Upload `Export-Local-Certificate-Inventory.ps1` as an Intune platform script. Run as system with 64-bit PowerShell.

## Expected Results

The script writes `LocalCertificateInventory.json` and exits 0 when inventory collection succeeds.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Local-Certificate-Inventory`. If a store is missing, verify the store path with `Get-ChildItem Cert:\LocalMachine`.
