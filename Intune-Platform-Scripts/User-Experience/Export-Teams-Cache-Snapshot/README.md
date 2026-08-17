# Export Teams Cache Snapshot

## Summary

This platform script writes a local JSON snapshot with configured Microsoft Teams cache folder existence, file count, and approximate size. It does not delete cache content.

## Files

- `Export-Teams-Cache-Snapshot.ps1` - Collects and writes Teams cache folder details.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$InventoryRoot` | Folder where the JSON snapshot is written. | `C:\ProgramData\IntuneScriptLibrary\Inventory` |
| `$InventoryFileName` | Output file name. | Includes current username |
| `$TeamsCacheFolders` | Cache folders included in the report. | New Teams and classic Teams cache paths |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- User context recommended when inspecting user profile cache paths.

## Customization

Add or remove cache paths in `$TeamsCacheFolders` to match the Teams client versions used in your tenant.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Export-Teams-Cache-Snapshot.ps1` |
| Run this script using the logged-on credentials | Yes |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy as an on-demand user experience troubleshooting helper.

## Expected Results

A JSON file exists at the configured inventory path and contains Teams cache folder size and file count details.

## Troubleshooting

- Run in user context when cache folders live under the user profile.
- If folders are missing, confirm whether the user has launched Teams.
- Review script logs and Intune Management Extension logs together.
