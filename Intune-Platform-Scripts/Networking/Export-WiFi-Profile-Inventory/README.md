# Export WiFi Profile Inventory

## Summary

This platform script writes a local JSON snapshot with Wi-Fi profile names and expected profile presence. It does not export wireless keys.

## Files

- `Export-WiFi-Profile-Inventory.ps1` - Collects and writes Wi-Fi profile inventory.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$InventoryRoot` | Folder where the JSON snapshot is written. | `C:\ProgramData\IntuneScriptLibrary\Inventory` |
| `$InventoryFileName` | Output file name. | `WiFiProfileInventory.json` |
| `$ExpectedProfileNames` | Profiles to highlight in the output. | `Contoso WiFi` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- WLAN profile support available on the target device.

## Customization

Replace `$ExpectedProfileNames` with the Wi-Fi profiles your technicians commonly check.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Export-WiFi-Profile-Inventory.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy as an on-demand Wi-Fi troubleshooting helper.

## Expected Results

A JSON file exists at the configured inventory path and lists local Wi-Fi profile names.

## Troubleshooting

- Confirm the device has WLAN components installed.
- Confirm the expected profile name is the profile name, not only the SSID.
- Review script logs and Intune Management Extension logs together.
