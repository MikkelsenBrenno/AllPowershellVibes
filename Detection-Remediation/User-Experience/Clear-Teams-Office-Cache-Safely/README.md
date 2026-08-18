# Clear Teams Office Cache Safely

## Summary

This remediation package detects old Teams and Office cache files across local user profiles. Remediation is reporting-only by default and deletes files only after `$DeleteCacheItems` is enabled.

## Files

- `Detect.ps1` - Finds old cache files.
- `Remediate.ps1` - Reports or removes old cache files.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$ExcludedProfileNames` | Profiles skipped during scanning. | Public and default profiles |
| `$MinimumCacheItemAgeDays` | Only target cache files older than this many days. | `7` |
| `$CacheRelativePaths` | Cache paths under each profile. | Teams and Office cache paths |
| `$DeleteCacheItems` | Actually delete matching files during remediation. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended to scan multiple user profiles.
- Pilot testing before enabling deletion.

## Customization

Add or remove cache paths in `$CacheRelativePaths`. Keep `$DeleteCacheItems` as `$false` until the detection output confirms the scope is correct.

Local user profiles are discovered through `Win32_UserProfile`, with the system drive's `Users` folder used as a fallback.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy in reporting-only mode first. Enable `$DeleteCacheItems` only after confirming the matched cache paths and age threshold.

## Exit Codes

- Detection `0` - No matching old cache files found.
- Detection `1` - Matching old cache files found.
- Remediation `0` - Files are absent, or deletion completes and the final rescan finds no matching files.
- Remediation `1` - Matching files remain or deletion failed.

## Expected Results

Old cache files are reported first and removed only when the explicit deletion switch is enabled.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Clear-Teams-Office-Cache-Safely`.
- Confirm Teams and Office are closed if files cannot be deleted.
- Increase `$MinimumCacheItemAgeDays` if the script targets too much data.

## Common Failures

- Cache files are locked by a running application.
- A redirected or non-local profile is not returned by `Win32_UserProfile` and is not present under the fallback profile root.
- `$DeleteCacheItems` is still disabled.
