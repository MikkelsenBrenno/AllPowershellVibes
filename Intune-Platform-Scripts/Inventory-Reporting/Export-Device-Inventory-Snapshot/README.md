# Export Device Inventory Snapshot

## Summary

This platform script writes a local JSON inventory snapshot with common hardware, OS, disk, and TPM details for technician troubleshooting.

## Files

- `Export-Device-Inventory-Snapshot.ps1` - Collects and writes the inventory snapshot.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$InventoryRoot` | Folder where the JSON snapshot is written. | `C:\ProgramData\IntuneScriptLibrary\Inventory` |
| `$InventoryFileName` | Output file name. | `DeviceInventorySnapshot.json` |
| `$SystemDriveLetter` | Drive letter to report disk capacity for. | `C` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Change `$InventoryRoot` if your technicians already use a standard local troubleshooting folder.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Export-Device-Inventory-Snapshot.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy as an on-demand or troubleshooting helper to devices where local inventory evidence is useful.

## Exit Codes

- `0` - Inventory snapshot was written.
- `1` - Inventory snapshot could not be written.

## Expected Results

A JSON file exists at the configured inventory path.

## What Success Looks Like

- The output file contains hardware, OS, disk, and TPM details.
- Logs exist under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-Device-Inventory-Snapshot`.

## Troubleshooting

- Confirm the script context can write to `$InventoryRoot`.
- Confirm WMI/CIM is healthy on the device.

## Common Failures

- Local WMI/CIM repository issues block inventory collection.
- The output folder is locked down by another security policy.
