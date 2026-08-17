# Defender: Enable Real-Time Protection

## Summary

This remediation package checks whether Microsoft Defender real-time protection is enabled and enables it when needed.

The script checks the inverted Defender preference `DisableRealtimeMonitoring`. A value of `$false` means real-time protection is enabled.

## Files

- `Detect.ps1` - Checks whether real-time protection is enabled.
- `Remediate.ps1` - Enables real-time protection and validates the final state.

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Microsoft Defender Antivirus available on the target device.
- PowerShell 5.1.
- System context recommended.
- 64-bit PowerShell recommended.

## Customization

Update the `CONFIGURATION` section in both scripts.

| Setting | Description | Default |
| --- | --- | --- |
| `$DefenderPreferenceName` | Defender preference checked by the script. | `DisableRealtimeMonitoring` |
| `$DesiredPreferenceValue` | Desired raw preference value. `$false` means enabled for this setting. | `$false` |
| `$ValidationDelaySeconds` | Wait time before remediation validation. | `3` |

## Intune Deployment

1. Go to Intune admin center.
2. Open **Devices > Manage devices > Scripts and remediations**.
3. Create a new script package.
4. Upload `Detect.ps1` as the detection script.
5. Upload `Remediate.ps1` as the remediation script.
6. Run as system.
7. Run in 64-bit PowerShell.
8. Assign to a pilot group before broad deployment.

## Expected Results

- Detection exits `0` when real-time protection is enabled.
- Detection exits `1` when remediation should run.
- Remediation exits `0` only after real-time protection is confirmed enabled.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Defender-Enable-Real-Time-Protection\Detect.log` and `Remediate.log`.
- Confirm Microsoft Defender Antivirus cmdlets are available.
- Check whether Tamper Protection, another policy, security baseline, or GPO controls this setting.
- Review Intune Management Extension logs in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
