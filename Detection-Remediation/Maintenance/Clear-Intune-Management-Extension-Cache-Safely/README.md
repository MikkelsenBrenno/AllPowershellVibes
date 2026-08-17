# Clear Intune Management Extension Cache Safely

## Summary

This remediation package detects old Intune Management Extension cache files and can remove them only after an explicit safety switch is enabled.

## Files

- `Detect.ps1` - Finds old cache files.
- `Remediate.ps1` - Reports or removes old cache files.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$CachePaths` | IME cache folders to scan. | IMECache and IME content staging paths |
| `$MinimumCacheItemAgeDays` | Only target files older than this many days. | `14` |
| `$ClearCacheItems` | Actually delete matching files. | `$false` |
| `$ExitZeroInReportingOnlyMode` | Exit successfully when only reporting. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.
- Pilot testing before enabling deletion.

## Customization

Review `$CachePaths` carefully for your IME version and tenant behavior. Leave `$ClearCacheItems` as `$false` until detection output confirms the scope.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy in reporting-only mode first, then enable `$ClearCacheItems` only after confirming the matched files are safe to remove.

## Exit Codes

- Detection `0` - No old cache files found.
- Detection `1` - Old cache files found.
- Remediation `0` - Files are absent or removed.
- Remediation `1` - Files remain, deletion failed, or deletion is disabled.

## Expected Results

Old IME cache files are reported first and removed only when explicitly enabled.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Clear-Intune-Management-Extension-Cache-Safely`.
- Confirm files are not locked by IME.
- Increase `$MinimumCacheItemAgeDays` if detection is too aggressive.

## Common Failures

- `$ClearCacheItems` is still disabled.
- IME is actively using files in the cache path.
- A customized cache path is too broad.
