# Export Endpoint Health Snapshot

## Summary

This platform script writes a local JSON snapshot with uptime, memory, disk, selected service state, and recent System error events.

## Files

- `Export-Endpoint-Health-Snapshot.ps1` - Collects and writes endpoint health details.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$InventoryRoot` | Folder where the JSON snapshot is written. | `C:\ProgramData\IntuneScriptLibrary\Inventory` |
| `$InventoryFileName` | Output file name. | `EndpointHealthSnapshot.json` |
| `$ServicesToReport` | Services included in the snapshot. | IME, Windows Update, BITS, Defender |
| `$RecentEventMinutes` | Recent System event window. | `120` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Adjust `$ServicesToReport` and `$RecentEventMinutes` to match your troubleshooting playbook.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Export-Endpoint-Health-Snapshot.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy as an on-demand endpoint health troubleshooting helper.

## Expected Results

A JSON file exists at the configured inventory path and contains endpoint health evidence.

## Troubleshooting

- Reduce `$RecentEventMinutes` if event collection is slow.
- Confirm WMI/CIM is healthy if OS or disk values are missing.
- Review script logs and Intune Management Extension logs together.
