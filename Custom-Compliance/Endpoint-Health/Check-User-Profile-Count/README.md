# Check-User-Profile-Count

## Summary

Reports whether the device has more local user profiles than your threshold allows. This is useful for shared devices, lab devices, kiosks, and older endpoints where profile buildup can consume disk space.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Test on a few device types before enforcing a profile count threshold.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$MaximumUserProfileCount`: Maximum allowed local profile count.
- `$IgnoreSpecialProfiles`: Exclude Windows special profiles.
- `$IgnoredProfilePathPatterns`: Profile paths that should not count toward compliance.

Also update `ComplianceRules.json` so the `UserProfileCount` operand matches `$MaximumUserProfileCount`.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `UserProfileCountCompliant` is `true` when the count is at or below the configured maximum.
- `ProfilePaths` lists the profile paths included in the count.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-User-Profile-Count`.

## Troubleshooting

- If the count is higher than expected, review `ProfilePaths` in the discovery output.
- If service or system profiles are counted, add path patterns to `$IgnoredProfilePathPatterns`.
- If compliance and script results disagree, verify the script threshold and rules file operand match.
- Use a separate stale-profile cleanup remediation only after pilot testing.
