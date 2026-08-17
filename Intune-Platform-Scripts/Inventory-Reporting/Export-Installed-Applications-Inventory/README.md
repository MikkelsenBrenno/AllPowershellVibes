# Export-Installed-Applications-Inventory

## Summary

Exports a local JSON inventory of machine-wide installed applications from the standard Windows uninstall registry locations. The output helps technicians compare app state, verify installs, and collect troubleshooting evidence.

## Prerequisites

- Deploy as an Intune platform script.
- Run in the system context.
- Run in 64-bit PowerShell so both 64-bit and WOW6432Node registry paths are visible.
- Confirm local inventory retention expectations with your organization before broad deployment.

## Customization

Edit the CONFIGURATION section near the top of the script:

- `$InventoryRoot`: Folder where the JSON inventory is written.
- `$InventoryFileName`: Output file name.
- `$IncludeSystemComponents`: Include hidden/system installer entries when set to `$true`.
- `$IncludeUpdates`: Include update, hotfix, and security update entries when set to `$true`.
- `$UninstallRegistryPaths`: Registry paths to scan.

## Intune Settings

- Script: `Export-Installed-Applications-Inventory.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`
- Assignment: Start with a pilot group before broad deployment.

## Expected Results

- Script exits `0` when the inventory file is written.
- Script exits `1` when inventory export fails.
- Inventory is written to `C:\ProgramData\IntuneScriptLibrary\Inventory\InstalledApplicationsInventory.json` by default.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Installed-Applications-Inventory`.

## Troubleshooting

- If the inventory is missing 32-bit applications, verify the script is running in 64-bit PowerShell.
- If the output contains too many installer entries, keep `$IncludeSystemComponents` and `$IncludeUpdates` set to `$false`.
- If the output file is missing, review the log folder for directory creation or file write errors.
- If a specific application is missing, confirm it registers under one of the configured uninstall registry paths.
