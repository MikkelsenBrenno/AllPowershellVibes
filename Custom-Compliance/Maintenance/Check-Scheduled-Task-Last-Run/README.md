# Check Scheduled Task Last Run

## Summary

This custom compliance package checks whether a configured scheduled task exists and has run successfully within the configured freshness window.

## Files

- `Discover.ps1` - Returns compressed JSON for Intune custom compliance.
- `ComplianceRules.json` - Intune custom compliance rule definition.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$TaskName` | Scheduled task name to inspect. | `Example Maintenance Task` |
| `$TaskPath` | Scheduled task path. | `\` |
| `$MaximumLastRunAgeDays` | Maximum allowed last run age. | `7` |
| `$ExpectedLastTaskResult` | Expected task result code. | `0` |
| `$TreatNeverRunAsCompliant` | Whether never-run tasks should pass. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- Scheduled Task cmdlets available.

## Customization

Replace `$TaskName` and `$TaskPath` with the scheduled task your organization wants to monitor.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Discovery script | `Discover.ps1` |
| Rules file | `ComplianceRules.json` |
| Run script as logged-on user | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to devices where a maintenance task or local collector must run regularly.

## Expected Results

Compliant devices return `ScheduledTaskLastRunCompliant` as `true`.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Scheduled-Task-Last-Run`.
- Confirm the task name and task path match exactly.
- Review Task Scheduler operational logs for task failures.

## Common Failures

- The task exists under a different task path.
- The task has never run.
- The task last result is non-zero.
