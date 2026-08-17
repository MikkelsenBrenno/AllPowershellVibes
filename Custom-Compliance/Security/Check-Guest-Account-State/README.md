# Check-Guest-Account-State

## Summary

Reports whether the built-in local Guest account is disabled. The script locates the account by SID suffix `-501`, so it works even when the account name is localized or renamed.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm whether any devices have an approved Guest-account exception before enforcing.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$GuestSidSuffix`: SID suffix used to locate the built-in Guest account.
- `$ExpectedGuestEnabledState`: Expected enabled state. Default `$false` means disabled.

Also update `ComplianceRules.json` if your expected state changes.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `GuestAccountCompliant` is `true` when the account enabled state matches policy.
- `GuestAccountName`, `GuestAccountSid`, and `GuestAccountEnabled` show the raw account data.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Guest-Account-State`.

## Troubleshooting

- If the account is not found, verify WMI can read local user accounts on the device.
- If the account name looks unexpected, check the SID to confirm it ends in `-501`.
- If compliance and script results disagree, verify the script expected state and rules file operand match.
- Use the matching remediation package only after exception review.
