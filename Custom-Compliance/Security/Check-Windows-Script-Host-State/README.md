# Check-Windows-Script-Host-State

## Summary

Reports whether Windows Script Host is disabled through the standard machine registry setting. This is useful when `.vbs` and `.js` script execution should be blocked on managed endpoints.

## Prerequisites

- Deploy as an Intune custom compliance discovery script.
- Run in the system context.
- Run in 64-bit PowerShell.
- Confirm whether any legacy workflows require Windows Script Host before enforcing.

## Customization

Edit the CONFIGURATION section near the top of `Discover.ps1`:

- `$WindowsScriptHostRegistryPath`: Registry path for Windows Script Host settings.
- `$EnabledValueName`: Registry value to inspect.
- `$ExpectedEnabledValue`: Expected value. Default `0` means disabled.

Also update `ComplianceRules.json` if your expected value changes.

## Intune Settings

- Discovery script: `Discover.ps1`
- Rules file: `ComplianceRules.json`
- Run this script using the logged-on credentials: `No`
- Enforce script signature check: `No`, unless your organization signs scripts
- Run script in 64-bit PowerShell: `Yes`

## Expected Results

- Output is compressed JSON.
- `WindowsScriptHostCompliant` is `true` when the registry value matches policy.
- `EnabledValue` shows the raw registry value.
- Logs are written to `C:\ProgramData\Microsoft\IntuneScriptLibrary\Logs\Check-Windows-Script-Host-State`.

## Troubleshooting

- If the registry path is missing, verify whether policy has ever created the setting.
- If scripts still run after setting the value, verify whether user-level settings override your test scenario.
- If compliance and script results disagree, verify the script expected value and rules file operand match.
- Use the matching remediation package only after compatibility testing.
