# Check-Local-Administrator-Count

## Summary

Reports whether the built-in local Administrators group contains more members than your policy allows. The discovery output includes both the count and the member names to help technicians identify what changed.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Review expected local administrator groups for your tenant before enforcing.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$MaximumAllowedAdministrators`: Maximum allowed member count.
- `$UseWellKnownAdministratorsSid`: Resolve the localized Administrators group name using SID `S-1-5-32-544`.
- `$FallbackAdministratorsGroupName`: Group name used if SID translation fails.
- `$ExcludedMemberNamePatterns`: Optional wildcard patterns to exclude from the count.

Also update `ComplianceRules.json` so the `LocalAdministratorCount` operand matches `$MaximumAllowedAdministrators`.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `LocalAdministratorCountCompliant` is `true` when the count is at or below the configured maximum.
- `LocalAdministratorMembers` lists the included members used for the count.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Local-Administrator-Count`.

## Troubleshooting

- If discovery fails, confirm the LocalAccounts PowerShell module is available.
- If group names look localized, keep `$UseWellKnownAdministratorsSid` set to `$true`.
- If known break-glass groups should not count, add them to `$ExcludedMemberNamePatterns`.
- If compliance and script results disagree, verify the script threshold and rules file operand match.
