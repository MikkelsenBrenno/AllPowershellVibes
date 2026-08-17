# Check Active Power Plan

## Summary

This custom compliance package checks whether the active Windows power plan GUID matches the configured expected value.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ExpectedPowerPlanGuid` | Power plan GUID expected on the device. | Balanced power plan GUID |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- `powercfg.exe` available on the target device.

## Customization

Replace `$ExpectedPowerPlanGuid` with the plan your organization expects for the device group, such as Balanced or High performance.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices where power plan drift should affect compliance.

## Expected Results

Compliant devices return `ActivePowerPlanCompliant` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Active-Power-Plan`.
- Confirm OEM power management tools are not changing the active plan.
- Confirm the expected GUID exists on the device.

## Common Failures

- The expected power plan does not exist on the device.
- Another policy changes the active plan after remediation.
- The device model uses custom OEM power plans.
