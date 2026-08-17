# Export-Network-Adapter-Inventory

## Summary

Exports local network adapter and IP configuration details to JSON. The output helps technicians verify MAC addresses, active IPs, gateways, DNS servers, and whether physical adapters are connected.

## Prerequisites

- Deploy as an Intune platform script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm local inventory retention expectations with your organization before broad deployment.

## Customization

Edit the CONFIGURATION section near the top of the script:

- `$InventoryRoot`: Folder where the JSON inventory is written.
- `$InventoryFileName`: Output file name.
- `$IncludeDisconnectedAdapters`: Include adapters without active IP configuration.
- `$IncludeNonPhysicalAdapters`: Include virtual and software adapters.

## Intune Settings

- Script: `Export-Network-Adapter-Inventory.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`
- Assignment: Start with a pilot group before broad deployment.

## Expected Results

- Script exits `0` when the inventory file is written.
- Script exits `1` when inventory export fails.
- Inventory is written to `C:\ProgramData\IntuneScriptLibrary\Inventory\NetworkAdapterInventory.json` by default.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Network-Adapter-Inventory`.

## Troubleshooting

- If expected adapters are missing, set `$IncludeDisconnectedAdapters` or `$IncludeNonPhysicalAdapters` to `$true`.
- If IP data is missing, confirm the adapter has an active network configuration.
- If the output file is missing, review the script log for directory creation or file write errors.
- Compare the JSON output with `ipconfig /all` during pilot testing.
