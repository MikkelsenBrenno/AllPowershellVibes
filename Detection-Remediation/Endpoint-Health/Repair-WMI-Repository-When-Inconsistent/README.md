# Repair WMI Repository When Inconsistent

## Summary

Detects inconsistent WMI repository state and can run a controlled salvage or reset action for devices where inventory and Intune scripts fail because WMI is unhealthy.

## Files

- `Detect.ps1` - Checks the current state.
- `Remediate.ps1` - Fixes or reports the issue when detection exits `1`.

## What To Change First

Open both scripts and review the `CONFIGURATION` section before changing anything else.

| Setting | Description | Default |
| --- | --- | --- |
| `$ExpectedVerificationText` | Text expected from WMI repository verification. | `consistent` |
| `$RepairMode` | Repair action. Use `ReportOnly`, `Salvage`, or `Reset`. | `Salvage` |
| `$ValidationDelaySeconds` | Wait time before remediation validation. | `10` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context.
- 64-bit PowerShell.
- Pilot carefully because WMI repository repair can affect local management instrumentation.

## Customization

Update the `CONFIGURATION` section in both scripts before deployment. Keep tenant-specific values, paths, profile names, and safety toggles near the top so technicians can review them immediately.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

1. Go to Intune admin center.
2. Open **Devices > Manage devices > Scripts and remediations**.
3. Create a script package.
4. Upload `Detect.ps1` as the detection script.
5. Upload `Remediate.ps1` as the remediation script.
6. Choose the settings above.
7. Assign to a small pilot group first.

## Expected Results

- Detection exits `0` when `winmgmt /verifyrepository` reports consistent.
- Remediation runs the configured repair action and validates with another verification pass.
- No reboot is triggered by the script.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Repair-WMI-Repository-When-Inconsistent`.
- Run the platform script `Export-WMI-Repository-Status` first when you only need a report.
- Check `Application` and `Microsoft-Windows-WMI-Activity` event logs if WMI remains unhealthy.

## Source Inspiration

Original implementation for this repository. Topic inspiration comes from WMI self-healing patterns in public Intune remediation examples such as [MSEndpointMgr/ProactiveRemediations](https://github.com/MSEndpointMgr/ProactiveRemediations) and [JayRHa/EndpointAnalyticsRemediationScripts](https://github.com/JayRHa/EndpointAnalyticsRemediationScripts).

