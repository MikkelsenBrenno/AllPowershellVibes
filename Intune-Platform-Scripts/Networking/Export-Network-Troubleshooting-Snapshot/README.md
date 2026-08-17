# Export Network Troubleshooting Snapshot

## Summary

This platform script writes a local JSON snapshot with adapter, IP, DNS, route, WinHTTP proxy, and basic connectivity details.

## Files

- `Export-Network-Troubleshooting-Snapshot.ps1` - Collects and writes network troubleshooting details.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$InventoryRoot` | Folder where the JSON snapshot is written. | `C:\ProgramData\IntuneScriptLibrary\Inventory` |
| `$InventoryFileName` | Output file name. | `NetworkTroubleshootingSnapshot.json` |
| `$ConnectivityTargets` | Hosts used for basic connectivity checks. | Microsoft public endpoints |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Replace `$ConnectivityTargets` with internal and external endpoints that matter for your tenant.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Export-Network-Troubleshooting-Snapshot.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy as an on-demand network troubleshooting helper.

## Expected Results

A JSON file exists at the configured inventory path and contains network state evidence.

## Troubleshooting

- Confirm endpoint names in `$ConnectivityTargets` are resolvable from the target network.
- If ping is blocked, treat connectivity results as advisory only.
- Review script logs and Intune Management Extension logs together.
