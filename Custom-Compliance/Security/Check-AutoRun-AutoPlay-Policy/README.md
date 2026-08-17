# Check-AutoRun-AutoPlay-Policy

## Summary

Reports whether machine-wide AutoRun and AutoPlay policy registry values match your endpoint hardening baseline. The default expects AutoRun to be disabled for all drive types.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm whether these values are already managed by Settings Catalog, GPO, or security baseline.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$ExplorerPolicyPath`: Registry path containing Explorer policy values.
- `$NoDriveTypeAutoRunValueName`: AutoRun drive-type value to inspect.
- `$ExpectedNoDriveTypeAutoRunValue`: Expected value. Default `255`.
- `$NoAutorunValueName`: NoAutorun value to inspect.
- `$ExpectedNoAutorunValue`: Expected NoAutorun value.
- `$RequireNoAutorunValue`: Require the NoAutorun value to exist and match.

Also update `ComplianceRules.json` if expected values change.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `AutoRunAutoPlayCompliant` is `true` when configured registry values match policy.
- `NoDriveTypeAutoRunValue` and `NoAutorunValue` show the raw registry values.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-AutoRun-AutoPlay-Policy`.

## Troubleshooting

- If the registry path is missing, verify whether policy has created it.
- If values revert, check GPO, Settings Catalog, or security baseline assignment.
- If compliance and script results disagree, verify script values and rules file operands match.
- Use a remediation package only after pilot testing because AutoPlay behavior is user-visible.
