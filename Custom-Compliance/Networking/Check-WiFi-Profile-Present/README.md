# Check WiFi Profile Present

## Summary

This custom compliance package checks whether a configured Wi-Fi profile name is present on the device.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ExpectedWiFiProfileName` | Wi-Fi profile name expected on the device. | `Contoso WiFi` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- WLAN profile support available on the target device.

## Customization

Replace `$ExpectedWiFiProfileName` with the exact profile name deployed by Intune, GPO, or another management channel.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices where Wi-Fi profile presence should affect compliance.

## Expected Results

Compliant devices return `WiFiProfilePresent` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-WiFi-Profile-Present`.
- Confirm the expected profile name matches exactly.
- Confirm WLAN AutoConfig is available and running on the device.

## Common Failures

- The device has no wireless adapter.
- The profile was deployed to user scope but the script runs as System.
- The profile name differs from the SSID.
