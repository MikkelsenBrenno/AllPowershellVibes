# Export-Local-Group-Membership-Inventory

## Summary

Exports local groups and group members to JSON. This helps technicians inspect local administrator drift, local support groups, remote access groups, and nested/domain principals visible on the endpoint.

## Prerequisites

- Deploy as an Intune platform script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm local inventory retention expectations with your organization before broad deployment.

## Customization

Edit the CONFIGURATION section near the top of the script:

- `$InventoryRoot`: Folder where the JSON inventory is written.
- `$InventoryFileName`: Output file name.
- `$IncludeEmptyGroups`: Include groups with no members.
- `$GroupNameAllowList`: Optional list of group names to include.
- `$GroupNameDenyList`: Optional list of group names to exclude.

## Intune Settings

- Script: `Export-Local-Group-Membership-Inventory.ps1`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`
- Assignment: Start with a pilot group before broad deployment.

## Expected Results

- Script exits `0` when the inventory file is written.
- Script exits `1` when inventory export fails.
- Inventory is written to `C:\ProgramData\IntuneScriptLibrary\Inventory\LocalGroupMembershipInventory.json` by default.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Local-Group-Membership-Inventory`.

## Troubleshooting

- If export fails, verify the LocalAccounts PowerShell module is available.
- If a group has no members, check whether `$IncludeEmptyGroups` is enabled.
- If a specific group is missing, review `$GroupNameAllowList` and `$GroupNameDenyList`.
- If member enumeration fails for one group, check `MemberQueryError` in the JSON output.
