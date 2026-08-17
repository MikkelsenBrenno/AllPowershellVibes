# Export BitLocker Inventory

## Summary

This platform script writes a local JSON inventory snapshot with BitLocker volume status, protection state, encryption status, and key protector types for technician troubleshooting.

## Files

- `Export-BitLocker-Inventory.ps1` - Collects and writes the BitLocker inventory snapshot.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$InventoryRoot` | Folder where the JSON snapshot is written. | `C:\ProgramData\IntuneScriptLibrary\Inventory` |
| `$InventoryFileName` | Output file name. | `BitLockerInventory.json` |
| `$MountPoints` | Optional list of volumes to inventory. Empty means all volumes. | `@()` |
| `$IncludeKeyProtectorIds` | Includes key protector IDs when set to `$true`. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.
- BitLocker PowerShell cmdlets available on the target device.

## Customization

Change `$InventoryRoot` if your technicians already use a standard local troubleshooting folder. Set `$MountPoints` to a specific list such as `@('C:')` when you only need the operating system drive.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Export-BitLocker-Inventory.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy as an on-demand or troubleshooting helper to devices where BitLocker evidence is useful.

## Exit Codes

- `0` - Inventory snapshot was written.
- `1` - Inventory snapshot could not be written.

## Expected Results

A JSON file exists at the configured inventory path and contains BitLocker volume inventory. Recovery passwords are not exported.

## What Success Looks Like

- The output file contains volume status, protection status, encryption percentage, and key protector type information.
- Logs exist under `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Export-BitLocker-Inventory`.

## Troubleshooting

- Confirm the script context can write to `$InventoryRoot`.
- Confirm the BitLocker PowerShell module is present on the device.
- If no volumes are returned, verify `$MountPoints` matches local mount points such as `C:`.
- Review script logs and Intune Management Extension logs together.

## Common Failures

- BitLocker cmdlets are unavailable on the target edition or image.
- The output folder is locked down by another security policy.
