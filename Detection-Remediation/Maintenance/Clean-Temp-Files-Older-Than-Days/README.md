# Clean Temp Files Older Than Days

## Summary

This remediation package detects and removes old files from configured cleanup paths.

## Files

- `Detect.ps1` - Counts cleanup candidate files.
- `Remediate.ps1` - Removes cleanup candidate files and validates the result.

## What To Change First

Open both scripts and review the `CONFIGURATION` section.

| Setting | Description | Default |
| --- | --- | --- |
| `$CleanupPaths` | Folders to scan for old files. | `C:\Windows\Temp` |
| `$MinimumFileAgeDays` | Minimum file age before cleanup. | `14` |
| `$Recurse` | Scan subfolders. | `$false` |
| `$DeleteCandidateFiles` | Actually delete candidate files. | `$true` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended for machine-level cleanup paths.

## Customization

Pilot with a narrow path first. Add more cleanup paths only after validating the logs.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | No unless your paths require it |

## Intune Deployment

1. Configure cleanup paths in both scripts.
2. Deploy to a pilot group.
3. Review logs before expanding scope.

## Exit Codes

- Detection `0` - No old files found.
- Detection `1` - Old files found.
- Remediation `0` - Old files removed or no cleanup required.
- Remediation `1` - Old files remain or cleanup failed.

## Expected Results

Files older than the configured age are removed from configured paths.

## What Success Looks Like

- Logs show candidate count before cleanup.
- Remediation exits `0` when no candidate files remain.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Clean-Temp-Files-Older-Than-Days`.
- Confirm cleanup paths exist on the device.
- Confirm files are not locked by another process.

## Common Failures

- Cleanup path is too broad.
- Files are locked and cannot be removed.
- Recursive cleanup is enabled without testing the folder contents first.
