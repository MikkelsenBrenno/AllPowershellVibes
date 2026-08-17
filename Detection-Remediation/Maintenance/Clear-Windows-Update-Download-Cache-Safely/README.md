# Clear Windows Update Download Cache Safely

## Summary

This remediation package detects old files in the Windows Update download cache and can remove them only after an explicit safety switch is enabled.

## Files

- `Detect.ps1` - Finds old cache files.
- `Remediate.ps1` - Reports or removes old cache files.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$CacheRoot` | Windows Update download cache path. | `%WINDIR%\SoftwareDistribution\Download` |
| `$MinimumCacheItemAgeDays` | Only target files older than this many days. | `14` |
| `$ClearCacheItems` | Actually delete matching files. | `$false` |
| `$StopUpdateServicesBeforeClearing` | Stop update services before deleting files. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.
- Pilot testing before enabling deletion.

## Customization

Leave `$ClearCacheItems` disabled until detection output confirms the scope. Enable service stopping only during a maintenance-friendly deployment window.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy in reporting-only mode first, then enable deletion after pilot validation.

## Exit Codes

- Detection `0` - No old cache files found.
- Detection `1` - Old cache files found.
- Remediation `0` - Files are absent or removed.
- Remediation `1` - Files remain, deletion failed, or deletion is disabled.

## Expected Results

Old Windows Update download cache files are reported first and removed only when explicitly enabled.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Clear-Windows-Update-Download-Cache-Safely`.
- Confirm update services are not actively using the files.
- Increase `$MinimumCacheItemAgeDays` if detection is too aggressive.

## Common Failures

- `$ClearCacheItems` is still disabled.
- Windows Update is actively downloading or installing updates.
- Files are locked by update services.
