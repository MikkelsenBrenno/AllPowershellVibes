# Check-Remote-Assistance-State

## Summary

Reports whether Remote Assistance is disabled through the standard registry setting. This gives technicians a quick compliance signal for devices where unsolicited or invitation-based assistance should not be enabled.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm whether any device groups are allowed to use Remote Assistance before enforcing.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$RemoteAssistanceRegistryPath`: Registry path containing the Remote Assistance setting.
- `$AllowHelpValueName`: Registry value to inspect.
- `$ExpectedAllowHelpValue`: Expected value. Default `0` means disabled.

Also update `ComplianceRules.json` if your expected value changes.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `RemoteAssistanceDisabled` is `true` when `fAllowToGetHelp` matches the expected value.
- `AllowHelpValue` shows the raw registry value.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Remote-Assistance-State`.

## Troubleshooting

- If the registry path is missing, verify the device OS and policy support.
- If the value is `1`, Remote Assistance invitations may be allowed.
- If compliance and script results disagree, verify the script expected value and rules file operand match.
- Use the matching remediation package to write the expected value after pilot testing.
