# Export Defender Security Snapshot

## Summary

This platform script writes a local JSON snapshot with Microsoft Defender status, signature, tamper protection, and selected preference values.

## Files

- `Export-Defender-Security-Snapshot.ps1` - Collects and writes Defender security details.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$InventoryRoot` | Folder where the JSON snapshot is written. | `C:\ProgramData\IntuneScriptLibrary\Inventory` |
| `$InventoryFileName` | Output file name. | `DefenderSecuritySnapshot.json` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Microsoft Defender PowerShell cmdlets available.
- System context recommended.

## Customization

Add or remove Defender preference fields based on what your technicians need for troubleshooting.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Export-Defender-Security-Snapshot.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy as an on-demand Defender troubleshooting helper.

## Expected Results

A JSON file exists at the configured inventory path and contains Microsoft Defender status evidence.

## Troubleshooting

- Confirm Microsoft Defender cmdlets are present on the target device.
- If tamper protection is blank, the local Defender status object may not expose the property.
- Review script logs and Intune Management Extension logs together.
