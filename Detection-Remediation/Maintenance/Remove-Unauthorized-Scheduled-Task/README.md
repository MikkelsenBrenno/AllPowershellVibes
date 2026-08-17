# Remove Unauthorized Scheduled Task

## Summary

This remediation package detects a configured unauthorized scheduled task and can remove it after an explicit safety switch is enabled.

## Files

- `Detect.ps1` - Checks whether the task exists.
- `Remediate.ps1` - Reports or removes the task.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$TaskName` | Scheduled task name. | `UnauthorizedExampleTask` |
| `$TaskPath` | Scheduled task path. | `\` |
| `$RemoveTask` | Actually remove the task. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Confirm the task path and name before enabling removal.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy in reporting-only mode first, then enable `$RemoveTask` after validation.

## Exit Codes

- Detection `0` - Task is absent.
- Detection `1` - Task exists.
- Remediation `0` - Task is absent or removed.
- Remediation `1` - Task remains.

## Expected Results

The unauthorized scheduled task is absent.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Remove-Unauthorized-Scheduled-Task`.
- Confirm the task path includes leading and trailing backslashes when needed.

## Common Failures

- The task name exists under a different task path.
- Removal is not enabled.
