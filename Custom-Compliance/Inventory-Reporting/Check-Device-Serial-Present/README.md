# Check Device Serial Present

## Summary

This custom compliance package checks whether the BIOS serial number is present and not one of several common generic placeholder values.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$InvalidSerialValues` | Generic serial values treated as invalid. | Common OEM placeholders |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- BIOS serial number exposed through WMI/CIM.

## Customization

Add organization-specific placeholder values to `$InvalidSerialValues` if your hardware inventory shows recurring bad data.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices where inventory quality matters for warranty, asset, or support workflows.

## Expected Results

Compliant devices return `DeviceSerialPresent` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Device-Serial-Present`.
- Compare the result with BIOS/UEFI and hardware inventory data.

## Common Failures

- Virtual machines report a placeholder serial number.
- OEM devices were imaged with generic BIOS data.
