# Example: Ensure Service Running

## Summary

This remediation package checks whether a Windows service is running and starts it when needed.

The default example monitors the Print Spooler service (`Spooler`). You can change the service name in the configuration section of both scripts.

## Files

- `Detect.ps1` - Checks whether the service is in the required status.
- `Remediate.ps1` - Sets the startup type if configured, starts the service, and validates the final state.

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- Intune Remediations licensing and permissions.
- PowerShell 5.1.
- System context recommended because service control usually requires administrative rights.

## Customization

Update the `CONFIGURATION` section in both scripts.

| Setting | Description | Default |
| --- | --- | --- |
| `$ServiceName` | Service name to check. Use the service name, not display name. | `Spooler` |
| `$RequiredStatus` | Status expected by detection. | `Running` |
| `$DesiredStartupType` | Startup type applied during remediation. | `Automatic` |
| `$StartServiceIfStopped` | Whether remediation should start the service. | `$true` |
| `$ValidationDelaySeconds` | Wait time before final validation. | `3` |

## Intune Deployment

1. Go to Intune admin center.
2. Open **Devices > Manage devices > Scripts and remediations**.
3. Create a new script package.
4. Upload `Detect.ps1` as the detection script.
5. Upload `Remediate.ps1` as the remediation script.
6. Run as system.
7. Run in 64-bit PowerShell. This script does not require it, but it is a safe default for machine-level checks.
8. Assign to a pilot device group.

## Expected Results

- If the service is running, detection exits `0` and remediation does not run.
- If the service is stopped, detection exits `1` and remediation runs.
- Remediation exits `0` only after the service is confirmed running.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Example-Ensure-Service-Running\Detect.log` and `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Example-Ensure-Service-Running\Remediate.log`.
- Confirm the configured service name exists on the target device.
- Confirm the service is not disabled by policy or dependent on another stopped service.
- Review Intune Management Extension logs in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
