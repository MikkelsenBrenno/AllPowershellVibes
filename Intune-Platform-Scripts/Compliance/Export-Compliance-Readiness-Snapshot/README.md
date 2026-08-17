# Export Compliance Readiness Snapshot

## Summary

This platform script writes a local JSON snapshot with common readiness signals used by compliance policies, including Windows build, Secure Boot, TPM, and Microsoft Defender state.

## Files

- `Export-Compliance-Readiness-Snapshot.ps1` - Collects and writes readiness details.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$InventoryRoot` | Folder where the JSON snapshot is written. | `C:\ProgramData\IntuneScriptLibrary\Inventory` |
| `$InventoryFileName` | Output file name. | `ComplianceReadinessSnapshot.json` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Add or remove readiness signals to match your compliance policy design.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Export-Compliance-Readiness-Snapshot.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy as an on-demand compliance troubleshooting helper.

## Expected Results

A JSON file exists at the configured inventory path and contains local readiness signals.

## Troubleshooting

- Confirm TPM and Secure Boot cmdlets are supported on the device model.
- Confirm Microsoft Defender cmdlets are available.
- Review script logs and Intune Management Extension logs together.
