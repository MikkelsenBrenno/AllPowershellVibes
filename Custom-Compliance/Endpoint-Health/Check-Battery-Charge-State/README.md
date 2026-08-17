# Check Battery Charge State

## Summary

This custom compliance package checks whether battery-powered devices have a charge level above a configurable threshold.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$MinimumChargePercent` | Minimum acceptable battery charge. | `20` |
| `$TreatNoBatteryAsCompliant` | Whether desktops and VMs without batteries should pass. | `$true` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Battery data available through WMI for portable devices.

## Customization

Adjust `$MinimumChargePercent` for kiosks, shared laptops, or field devices.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to laptop or mobile workstation groups where low charge status should be visible.

## Expected Results

Compliant devices return `BatteryChargeCompliant` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Battery-Charge-State`.
- Confirm the target device exposes `Win32_Battery`.

## Common Failures

- Virtual machines do not expose battery data.
- The compliance threshold is too high for normal field use.
