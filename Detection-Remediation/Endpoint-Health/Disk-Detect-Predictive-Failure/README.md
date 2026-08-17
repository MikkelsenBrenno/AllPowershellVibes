# Disk: Detect Predictive Failure

## Summary

This remediation package detects predictive failure signals for the disk where Windows is installed.

The detection script resolves the Windows/system drive, normally `C:`, to its backing physical disk and checks only that disk. It checks SMART predictive failure data from `MSStorageDriver_FailurePredictStatus` and can optionally use Windows disk health as a fallback. The remediation script does not try to repair hardware. It logs the finding, optionally sends a Teams alert, and keeps Intune reporting the issue until an admin takes action.

## Files

- `Detect.ps1` - Detects SMART predictive failure or unhealthy disk state for the Windows disk.
- `Remediate.ps1` - Rechecks the Windows disk state, logs details, and optionally sends a Teams alert.

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.
- 64-bit PowerShell recommended.
- Hardware and driver support for SMART or Windows Storage health reporting.

## Customization

Update the `CONFIGURATION` section in both scripts.

| Setting | Description | Default |
| --- | --- | --- |
| `$CheckSmartPredictiveFailure` | Checks `MSStorageDriver_FailurePredictStatus` in `root\wmi`. | `$true` |
| `$TargetDriveLetter` | Drive letter to resolve and check. Defaults to the Windows system drive. | `$env:SystemDrive` |
| `$CheckDiskHealthFallback` | Uses `Win32_DiskDrive` and `Get-Disk` as fallback health sources for the Windows disk. | `$true` |
| `$UnhealthyDiskHealthStatuses` | `Get-Disk` health states treated as noncompliant. | `Warning`, `Unhealthy` |
| `$UnhealthyDiskOperationalStatuses` | `Get-Disk` operational states treated as noncompliant. | `Predictive Failure` |
| `$UnhealthyWin32DiskStatuses` | `Win32_DiskDrive` status values treated as noncompliant. | `Pred Fail`, `Error`, `Degraded` |
| `$ExitOneWhenPredictiveFailureRemains` | Keeps remediation reporting failed until manual action is taken. | `$true` |

The remediation script also includes the optional Teams alert block. It is disabled by default:

```powershell
$EnableTeamsFailureAlert = $false
$TeamsWebhookUrl = ''
```

Admins can enable it in their deployed copy and provide their own webhook URL. The default flow tag is:

```text
INTUNE_DISK_PREDICTIVE_FAILURE
```

Teams alert throttling is enabled by default and allows one alert per device/script/flow tag every 24 hours.

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

- Detection exits `0` when no predictive failure is detected for the Windows disk.
- Detection exits `1` when predictive failure or unhealthy disk state is detected for the Windows disk.
- Remediation exits `0` when the issue is no longer detected.
- Remediation exits `1` by default when predictive failure remains, because manual hardware action is required.
- If Teams alerting is enabled, the remediation script sends an alert and then throttles repeated alerts for 24 hours.

## Operational Guidance

A predictive disk failure should be treated as a hardware risk. Recommended actions:

- Confirm the finding with vendor diagnostics when available.
- Back up user data.
- Review warranty or replacement process.
- Replace the disk or device.
- Re-run detection after the hardware issue is resolved.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Disk-Detect-Predictive-Failure\Detect.log` and `Remediate.log`.
- Confirm the device exposes SMART data through `root\wmi`.
- Confirm the Windows drive can be resolved with `Win32_LogicalDisk` associations.
- Confirm `Get-Disk` works in 64-bit PowerShell if fallback health checks are enabled.
- Review Intune Management Extension logs in `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs`.
- If Teams alerts do not send, confirm `$EnableTeamsFailureAlert`, `$TeamsWebhookUrl`, tenant policy, and alert throttling state.
