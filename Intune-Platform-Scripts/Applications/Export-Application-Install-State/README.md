# Export Application Install State

## Summary

This platform script writes a local JSON snapshot showing whether configured application name patterns are present in common machine-wide uninstall registry locations.

## Files

- `Export-Application-Install-State.ps1` - Collects and writes application install state.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$InventoryRoot` | Folder where the JSON snapshot is written. | `C:\ProgramData\IntuneScriptLibrary\Inventory` |
| `$InventoryFileName` | Output file name. | `ApplicationInstallState.json` |
| `$ApplicationNamePatterns` | Application display name text to search for. | Microsoft 365 Apps, Edge, Company Portal |
| `$UninstallRegistryPaths` | Registry paths to inspect. | HKLM uninstall paths |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Replace `$ApplicationNamePatterns` with the apps your technicians need to check most often.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Export-Application-Install-State.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy as an on-demand application troubleshooting helper.

## Expected Results

A JSON file exists at the configured inventory path and lists match state for each configured app pattern.

## Troubleshooting

- Confirm the app registers in uninstall registry keys.
- Adjust patterns when display names differ by language, channel, or vendor.
- Review script logs and Intune Management Extension logs together.
