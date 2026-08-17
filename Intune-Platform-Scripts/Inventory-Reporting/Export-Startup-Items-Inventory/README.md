# Export-Startup-Items-Inventory

## Summary

Exports machine-wide startup registry entries and all-users Startup folder items to JSON. This helps technicians inspect launch-at-logon behavior during malware triage, app troubleshooting, or performance investigations.

## Prerequisites

- Deploy as an Intune platform script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm local inventory retention expectations with your organization before broad deployment.

## Customization

Edit the CONFIGURATION section near the top of the script:

- `$InventoryRoot`: Folder where the JSON inventory is written.
- `$InventoryFileName`: Output file name.
- `$StartupRegistryPaths`: Registry Run keys to inspect.
- `$StartupFolderPaths`: Startup folders to inspect.
- `$PropertyNamesToIgnore`: PowerShell provider properties excluded from registry output.

## Intune Settings

- Script: `Export-Startup-Items-Inventory.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`
- Assignment: Start with a pilot group before broad deployment.

## Expected Results

- Script exits `0` when the inventory file is written.
- Script exits `1` when inventory export fails.
- Inventory is written to `C:\ProgramData\IntuneScriptLibrary\Inventory\StartupItemsInventory.json` by default.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Startup-Items-Inventory`.

## Troubleshooting

- If expected entries are missing, verify the registry path or startup folder is included.
- If user-specific entries are needed, add the correct user hive or run a user-context variant.
- If output is larger than expected, narrow `$StartupRegistryPaths` and `$StartupFolderPaths`.
- Compare the JSON output with Task Manager Startup apps during pilot testing.
