# Export Service Startup Inventory

## Summary

Exports Windows service startup details to a local JSON file. This helps technicians compare service state, start mode, service account, and executable path during endpoint health troubleshooting.

## Prerequisites

Run in the system context with 64-bit PowerShell for complete service visibility.

## Customization

Edit the CONFIGURATION section in `Export-Service-Startup-Inventory.ps1`.

- `$OutputRoot`: Folder where the JSON file is written.
- `$OutputFileName`: Inventory file name.
- `$IncludeOnlyNonDefaultStartModes`: Optional filter switch.
- `$NonDefaultStartModes`: Start modes included when filtering is enabled.

## Intune Settings

Upload `Export-Service-Startup-Inventory.ps1` as an Intune platform script. Run as system with 64-bit PowerShell.

## Expected Results

The script writes `ServiceStartupInventory.json` and exits 0 when inventory collection succeeds.

## Troubleshooting

Check logs under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Service-Startup-Inventory`. If the file is missing, verify that the configured output folder can be created under ProgramData.
