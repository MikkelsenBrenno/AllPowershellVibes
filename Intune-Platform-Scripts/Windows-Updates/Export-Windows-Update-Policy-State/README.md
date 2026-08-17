# Export Windows Update Policy State

## Summary

This platform script writes a local JSON snapshot of common Windows Update policy registry paths for update ring, target release, active hours, and update source troubleshooting.

## Files

- `Export-Windows-Update-Policy-State.ps1` - Collects and writes Windows Update policy state.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$InventoryRoot` | Folder where the JSON snapshot is written. | `C:\ProgramData\IntuneScriptLibrary\Inventory` |
| `$InventoryFileName` | Output file name. | `WindowsUpdatePolicyState.json` |
| `$PolicyRegistryPaths` | Windows Update policy paths to inspect. | WindowsUpdate and AU policy keys |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Add tenant-specific policy paths to `$PolicyRegistryPaths` when your update troubleshooting checklist includes extra registry locations.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Export-Windows-Update-Policy-State.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy as an on-demand Windows Update policy troubleshooting helper.

## Expected Results

A JSON file exists at the configured inventory path and contains registry policy state for each configured path.

## Troubleshooting

- Confirm Intune policy has synced before collecting evidence.
- Confirm GPO is not overwriting Windows Update for Business values.
- Review script logs and Intune Management Extension logs together.
