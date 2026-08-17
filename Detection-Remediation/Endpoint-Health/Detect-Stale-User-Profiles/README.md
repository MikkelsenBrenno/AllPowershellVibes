# Detect Stale User Profiles

## Summary

This remediation package detects local user profiles older than a configured age. Removal is disabled by default.

## Files

- `Detect.ps1` - Finds stale profiles.
- `Remediate.ps1` - Reports stale profiles or removes them when enabled.

## What To Change First

| Setting | Description | Default |
| --- | --- | --- |
| `$StaleProfileAgeDays` | Age threshold for stale profiles. | `90` |
| `$IgnoreSpecialProfiles` | Skip system/special profiles. | `$true` |
| `$IgnoreLoadedProfiles` | Skip currently loaded profiles. | `$true` |
| `$DeleteStaleProfiles` | Actually delete stale profiles. | `$false` |

## Prerequisites

- Windows device enrolled in Microsoft Intune.
- PowerShell 5.1.
- System context recommended.

## Customization

Pilot in reporting-only mode before enabling deletion.

## Intune Settings

| Setting | Recommended value |
| --- | --- |
| Script type | Remediation |
| Detection script | `Detect.ps1` |
| Remediation script | `Remediate.ps1` |
| Run this script using the logged-on credentials | No |
| Run script in 64-bit PowerShell | Yes |

## Intune Deployment

Deploy to a pilot group and inspect logs before enabling `$DeleteStaleProfiles`.

## Exit Codes

- Detection `0` - No stale profiles found.
- Detection `1` - Stale profiles found.
- Remediation `0` - No stale profiles remain or reporting-only success is enabled.
- Remediation `1` - Stale profiles remain or cleanup failed.

## Expected Results

Stale profile paths are logged for review, and optionally removed after explicit enablement.

## Troubleshooting

- Review logs in `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Detect-Stale-User-Profiles`.
- Confirm loaded profiles are skipped before deletion.
- Confirm age threshold is appropriate for shared devices.

## Common Failures

- Deletion is enabled before validating excluded profiles.
- Profiles are loaded and cannot be removed safely.
