# Clean Old Script Logs

## Summary

This platform script reports or removes old Intune script library log files under a configurable folder. It starts in report-only mode.

## Files

- `Clean-Old-Script-Logs.ps1` - Reports or removes old log files.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$TargetLogRoot` | Folder searched for old logs. | `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs` |
| `$FileNamePatterns` | File patterns included in cleanup. | `*.log`, `*.txt` |
| `$OlderThanDays` | Minimum file age before cleanup. | `30` |
| `$ApplyCleanup` | Set to `$true` to remove files. | `$false` |
| `$MaximumFilesToProcess` | Safety cap for one run. | `500` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Pilot with `$ApplyCleanup = $false`, review logs, then set `$ApplyCleanup = $true` when the target folder is approved.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Platform script |
| Script file | `Clean-Old-Script-Logs.ps1` |
| Run this script using the logged-on credentials | No |
| Enforce script signature check | Tenant policy |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy as a periodic maintenance helper after validating the target log path.

## Expected Results

The script reports candidate files by default and removes them only when `$ApplyCleanup` is enabled.

## Troubleshooting

- Confirm `$TargetLogRoot` is the intended folder.
- Increase `$MaximumFilesToProcess` only after reviewing candidate count.
- Review script logs and Intune Management Extension logs together.
