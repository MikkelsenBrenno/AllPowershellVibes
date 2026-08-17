# Defender: Enable PUA Protection

## Summary

This remediation package checks whether Microsoft Defender potentially unwanted application protection is enabled and enables it when needed.

The default desired state is `Enabled`.

## Files

- `Detect.ps1` - Checks the current `PUAProtection` value.
- `Remediate.ps1` - Sets `PUAProtection` to the configured desired value and validates it.

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
| `$DesiredPUAProtection` | Desired PUA protection state. Use `Enabled`, `Disabled`, or `AuditMode`. | `Enabled` |
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

- Detection exits `0` when PUA protection matches the desired state.
- Detection exits `1` when remediation should run.
- Remediation exits `0` only after the desired value is confirmed.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Defender-Enable-PUA-Protection\Detect.log` and `Remediate.log`.
- Confirm Microsoft Defender Antivirus cmdlets are available.
- Check whether another policy, security baseline, or GPO controls this setting.
- Review Intune Management Extension logs in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
