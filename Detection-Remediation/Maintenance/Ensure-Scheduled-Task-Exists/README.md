# Ensure Scheduled Task Exists

## Summary

This remediation package creates or updates a scheduled task with a configurable action and trigger.

## Files

- `Detect.ps1` - Checks whether the scheduled task exists with the expected action.
- `Remediate.ps1` - Creates or updates the scheduled task and validates it.

## What To Change First

Open both scripts and review the `CONFIGURATION` section.

| Setting | Description | Default |
| --- | --- | --- |
| `$TaskName` | Scheduled task name. | `IntuneScriptLibraryExample` |
| `$TaskPath` | Scheduled task folder path. | `\IntuneScriptLibrary\` |
| `$ActionExecutable` | Executable run by the task. | Windows PowerShell |
| `$ActionArguments` | Arguments passed to the executable. | Example command |
| `$TriggerType` | Trigger type. | `AtStartup` |
| `$RunAsUserId` | Account used by the task. | `SYSTEM` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended when creating machine-level tasks.

## Customization

Keep the task name, path, action, arguments, trigger, and run-as identity aligned between detection and remediation.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

1. Customize the task action and trigger.
2. Deploy to a pilot group.
3. Confirm the task appears in Task Scheduler under the configured path.

## Exit Codes

- Detection `0` - Task exists with expected action.
- Detection `1` - Task is missing or different.
- Remediation `0` - Task was created or updated and validated.
- Remediation `1` - Task could not be created or validated.

## Expected Results

The scheduled task exists under the configured path and runs the configured action.

## What Success Looks Like

- Logs show the task path, name, action, and arguments.
- Remediation exits `0` after validating the task action.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Ensure-Scheduled-Task-Exists`.
- Confirm the task action path exists on target devices.
- Confirm quoting in `$ActionArguments` is correct.

## Common Failures

- Detection and remediation use different task arguments.
- The task action references a path that does not exist.
- The task runs as a user that does not have permission to execute the action.
